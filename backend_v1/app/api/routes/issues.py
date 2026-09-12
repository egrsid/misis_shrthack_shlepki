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
from app.models import Issue
from app.schemas import (
    AnalyzeRequest,
    GenerateReplyResponse,
    IssueOut,
    IssueUpdate,
    ReplyCreate,
    ReplyResponse,
)
from app.services.llm import analyze_text, draft_reply

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


@router.post("/analyze", response_model=list[IssueOut], status_code=status.HTTP_201_CREATED)
def analyze_request(payload: AnalyzeRequest, db: Session = Depends(get_db)):
    """Split a customer message, save each issue, and return them to Swift."""
    try:
        extracted_issues = analyze_text(payload.text)
    except Exception as error:
        raise llm_error(error) from error

    issues = [
        Issue(
            user_id=payload.user_id,
            original_text=payload.text,
            title=item.title,
            description=item.description,
            category=item.category,
            priority=item.priority,
            status="new",
        )
        for item in extracted_issues
    ]
    db.add_all(issues)
    db.commit()
    for issue in issues:
        db.refresh(issue)
    return issues


@router.get("/issues", response_model=list[IssueOut])
def list_issues(db: Session = Depends(get_db)):
    return db.scalars(select(Issue).order_by(Issue.created_at.desc())).all()


@router.get("/users/{user_id}/issues", response_model=list[IssueOut])
def list_user_issues(user_id: int, db: Session = Depends(get_db)):
    return db.scalars(
        select(Issue).where(Issue.user_id == user_id).order_by(Issue.created_at.desc())
    ).all()


@router.patch("/issues/{issue_id}", response_model=IssueOut)
def update_issue(issue_id: int, payload: IssueUpdate, db: Session = Depends(get_db)):
    issue = get_issue_or_404(db, issue_id)
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=400, detail="Send at least one field to update")
    for field, value in changes.items():
        setattr(issue, field, value)
    db.commit()
    db.refresh(issue)
    return issue


@router.post("/issues/{issue_id}/generate-reply", response_model=GenerateReplyResponse)
def generate_reply(issue_id: int, db: Session = Depends(get_db)):
    issue = get_issue_or_404(db, issue_id)
    try:
        reply = draft_reply(issue.title, issue.description, issue.category)
    except Exception as error:
        raise llm_error(error) from error
    issue.generated_reply = reply
    db.commit()
    db.refresh(issue)
    return {"issue": issue, "reply": reply}


@router.post("/issues/{issue_id}/reply", response_model=ReplyResponse)
def save_reply(
    issue_id: int,
    payload: ReplyCreate,
    db: Session = Depends(get_db),
):
    """Save the operator's final reply; this does not call the LLM."""
    issue = get_issue_or_404(db, issue_id)
    issue.final_reply = payload.text.strip()
    db.commit()
    db.refresh(issue)
    return {"issue": issue, "reply": issue.final_reply}
