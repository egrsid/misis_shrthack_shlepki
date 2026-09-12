import json
import uuid
from collections.abc import Sequence

from fastapi import APIRouter, Depends, HTTPException, status
from openai import (
    APIConnectionError,
    APIStatusError,
    AuthenticationError,
    BadRequestError,
    PermissionDeniedError,
    RateLimitError,
)
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.triage import (
    COLLECTING,
    clarification_text,
    clean_slots,
    missing_fields,
    status_after_edit,
    status_for,
    visible_slots,
)
from app.models import Issue
from app.schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    ClarifyRequest,
    GenerateReplyResponse,
    IssueOut,
    IssueUpdate,
    ReplyCreate,
    ReplyResponse,
)
from app.services.llm import analyze_text, draft_reply, extract_slots

router = APIRouter(tags=["issues"])


def get_issue_or_404(db: Session, issue_id: int) -> Issue:
    issue = db.get(Issue, issue_id)
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")
    return issue


def llm_error(error: Exception) -> HTTPException:
    if isinstance(error, AuthenticationError):
        return HTTPException(status_code=401, detail="Yandex API key is invalid.")
    if isinstance(error, PermissionDeniedError):
        return HTTPException(
            status_code=403,
            detail="The service account has no access to Yandex AI Studio.",
        )
    if isinstance(error, RateLimitError):
        return HTTPException(
            status_code=429,
            detail="Yandex AI Studio quota or rate limit exceeded.",
        )
    if isinstance(error, BadRequestError):
        return HTTPException(status_code=400, detail=f"Yandex AI error: {error.message}")
    if isinstance(error, APIConnectionError):
        return HTTPException(
            status_code=503,
            detail="Cannot connect to Yandex AI Studio. Check the internet connection.",
        )
    if isinstance(error, APIStatusError):
        return HTTPException(
            status_code=502,
            detail=f"Yandex AI Studio returned HTTP {error.status_code}.",
        )
    return HTTPException(status_code=500, detail=str(error))


# --- JSON columns -----------------------------------------------------------
# slots and missing live as JSON text in SQLite; these helpers keep the parsing
# in one place and tolerate rows written before the columns existed.


def load_slots(issue: Issue) -> dict[str, str | None]:
    if not issue.slots:
        return {}
    try:
        data = json.loads(issue.slots)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def load_missing(issue: Issue) -> list[str]:
    if not issue.missing:
        return []
    try:
        data = json.loads(issue.missing)
    except json.JSONDecodeError:
        return []
    return [str(item) for item in data] if isinstance(data, list) else []


def apply_triage(issue: Issue, slots: dict[str, str | None]) -> list[str]:
    """Store slots and recompute the missing list. The rules decide, not the LLM."""
    cleaned = clean_slots(slots)
    missing = missing_fields(issue.category, cleaned)
    issue.slots = json.dumps(cleaned, ensure_ascii=False)
    issue.missing = json.dumps(missing, ensure_ascii=False)
    return missing


def group_positions(db: Session, issues: Sequence[Issue]) -> dict[str, list[int]]:
    """Map every request_id in play to its issue ids, ordered, for "1 of 3" badges."""
    request_ids = {issue.request_id for issue in issues if issue.request_id}
    if not request_ids:
        return {}
    rows = db.execute(
        select(Issue.request_id, Issue.id)
        .where(Issue.request_id.in_(request_ids))
        .order_by(Issue.request_id, Issue.id)
    ).all()
    positions: dict[str, list[int]] = {}
    for request_id, issue_id in rows:
        positions.setdefault(request_id, []).append(issue_id)
    return positions


def to_out(issue: Issue, positions: dict[str, list[int]]) -> IssueOut:
    slots = load_slots(issue)
    ids = positions.get(issue.request_id or "", [])
    index = ids.index(issue.id) + 1 if issue.id in ids else 1
    return IssueOut(
        id=issue.id,
        user_id=issue.user_id,
        original_text=issue.original_text,
        title=issue.title,
        description=issue.description,
        category=issue.category,
        priority=issue.priority,
        status=issue.status,
        slots=visible_slots(issue.category, slots),
        missing=load_missing(issue),
        generated_reply=issue.generated_reply,
        final_reply=issue.final_reply,
        request_id=issue.request_id,
        group_index=index,
        group_total=len(ids) or 1,
        created_at=issue.created_at,
        updated_at=issue.updated_at,
    )


def serialize(db: Session, issues: Sequence[Issue]) -> list[IssueOut]:
    positions = group_positions(db, issues)
    return [to_out(issue, positions) for issue in issues]


def serialize_one(db: Session, issue: Issue) -> IssueOut:
    return to_out(issue, group_positions(db, [issue]))


# --- endpoints --------------------------------------------------------------


@router.post("/analyze", response_model=AnalyzeResponse, status_code=status.HTTP_201_CREATED)
def analyze_request(payload: AnalyzeRequest, db: Session = Depends(get_db)):
    """Split a customer message into issues, triage each one, save them all.

    The LLM only splits the text and extracts entities. Which fields are missing,
    which status each issue gets and what the customer is asked are all decided here.
    """
    try:
        extracted_issues = analyze_text(payload.text)
    except Exception as error:
        raise llm_error(error) from error

    request_id = str(uuid.uuid4())
    issues: list[Issue] = []
    gaps: list[tuple[str, list[str]]] = []

    for item in extracted_issues:
        issue = Issue(
            user_id=payload.user_id,
            original_text=payload.text,
            request_id=request_id,
            title=item.title,
            description=item.description,
            category=item.category,
            priority=item.priority,
        )
        missing = apply_triage(issue, item.slots.model_dump())
        issue.status = status_for(missing)
        issues.append(issue)
        gaps.append((item.category, missing))

    db.add_all(issues)
    db.commit()
    for issue in issues:
        db.refresh(issue)

    return AnalyzeResponse(
        request_id=request_id,
        issues=serialize(db, issues),
        clarification=clarification_text(gaps),
        # Only complete issues reach the operator; the rest wait in the chat.
        submitted=[issue.id for issue in issues if issue.status != COLLECTING],
    )


@router.post("/requests/{request_id}/clarify", response_model=AnalyzeResponse)
def clarify_request(
    request_id: str,
    payload: ClarifyRequest,
    db: Session = Depends(get_db),
):
    """Apply the customer's answer to the issues still waiting for data.

    The LLM only pulls values out of the answer; whether that is now enough to
    hand an issue to the operator is decided by the rules.
    """
    issues = db.scalars(
        select(Issue).where(Issue.request_id == request_id).order_by(Issue.id)
    ).all()
    if not issues:
        raise HTTPException(status_code=404, detail="Request not found")

    pending = [issue for issue in issues if issue.status == COLLECTING]
    if not pending:
        raise HTTPException(
            status_code=409,
            detail="This request has already been handed to an operator.",
        )

    needed = sorted({field for issue in pending for field in load_missing(issue)})
    try:
        extracted = extract_slots(payload.text, needed)
    except Exception as error:
        raise llm_error(error) from error

    provided = {
        key: value
        for key, value in clean_slots(extracted.model_dump()).items()
        if value is not None and key in set(needed)
    }

    submitted: list[int] = []
    gaps: list[tuple[str, list[str]]] = []
    for issue in pending:
        slots = load_slots(issue)
        # Only fields this issue actually asked for; an answer about the warranty
        # must not silently fill a different issue's order number.
        for field in load_missing(issue):
            if field in provided:
                slots[field] = provided[field]
        missing = apply_triage(issue, slots)
        issue.status = status_for(missing)
        # Keep the answer with the issue so the operator reads the full exchange.
        issue.original_text = f"{issue.original_text}\n\nУточнение клиента: {payload.text.strip()}"
        if missing:
            gaps.append((issue.category, missing))
        else:
            submitted.append(issue.id)

    db.commit()
    for issue in issues:
        db.refresh(issue)

    return AnalyzeResponse(
        request_id=request_id,
        issues=serialize(db, issues),
        clarification=clarification_text(gaps),
        submitted=submitted,
    )


@router.get("/issues", response_model=list[IssueOut])
def list_issues(include_collecting: bool = False, db: Session = Depends(get_db)):
    """The operator's feed.

    Issues still being clarified in the chat are excluded: an incomplete request
    is not the operator's work yet. include_collecting=true is for debugging.
    """
    query = select(Issue).order_by(Issue.created_at.desc(), Issue.id.desc())
    if not include_collecting:
        query = query.where(Issue.status != COLLECTING)
    return serialize(db, db.scalars(query).all())


@router.get("/users/{user_id}/issues", response_model=list[IssueOut])
def list_user_issues(user_id: int, db: Session = Depends(get_db)):
    issues = db.scalars(
        select(Issue)
        .where(Issue.user_id == user_id)
        .order_by(Issue.created_at.desc(), Issue.id.desc())
    ).all()
    return serialize(db, issues)


@router.get("/issues/{issue_id}", response_model=IssueOut)
def get_issue(issue_id: int, db: Session = Depends(get_db)):
    return serialize_one(db, get_issue_or_404(db, issue_id))


@router.patch("/issues/{issue_id}", response_model=IssueOut)
def update_issue(issue_id: int, payload: IssueUpdate, db: Session = Depends(get_db)):
    """Edit an issue. Filling in a slot re-runs triage, so the red fields clear
    themselves and an awaiting_info issue becomes workable again."""
    issue = get_issue_or_404(db, issue_id)
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=400, detail="Send at least one field to update")

    slot_changes = changes.pop("slots", None)
    for field, value in changes.items():
        setattr(issue, field, value)

    # Recompute whenever the slots or the category (and so the requirements) move.
    if slot_changes is not None or "category" in changes:
        slots = load_slots(issue)
        slots.update(slot_changes or {})
        missing = apply_triage(issue, slots)
        if "status" not in changes:
            issue.status = status_after_edit(issue.status, missing)

    db.commit()
    db.refresh(issue)
    return serialize_one(db, issue)


@router.post("/issues/{issue_id}/generate-reply", response_model=GenerateReplyResponse)
def generate_reply(issue_id: int, db: Session = Depends(get_db)):
    issue = get_issue_or_404(db, issue_id)
    try:
        reply = draft_reply(
            issue.title,
            issue.description,
            issue.category,
            slots=load_slots(issue),
            missing=load_missing(issue),
        )
    except Exception as error:
        raise llm_error(error) from error
    issue.generated_reply = reply
    db.commit()
    db.refresh(issue)
    return GenerateReplyResponse(issue=serialize_one(db, issue), reply=reply)


@router.post("/issues/{issue_id}/reply", response_model=ReplyResponse)
def save_reply(
    issue_id: int,
    payload: ReplyCreate,
    db: Session = Depends(get_db),
):
    """Save the operator's final reply; this does not call the LLM."""
    issue = get_issue_or_404(db, issue_id)
    issue.final_reply = payload.text.strip()
    # Sending the approved answer is what closes the issue.
    if issue.status not in {"resolved", "closed"}:
        issue.status = "resolved"
    db.commit()
    db.refresh(issue)
    return ReplyResponse(issue=serialize_one(db, issue), reply=issue.final_reply)
