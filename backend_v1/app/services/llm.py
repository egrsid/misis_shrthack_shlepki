from openai import OpenAI

from app.core.config import settings
from app.schemas.issue import ExtractedIssue, IssueAnalysis, IssueSlots

from .fake_llm import fake_analyze, fake_extract_slots, fake_reply


ANALYZE_INSTRUCTIONS = """You are an AI triage assistant for an electronics store support team.
Split one customer message into separate, independent support issues: every distinct problem,
question or request becomes its own issue. Use Russian, because the customer writes in Russian.

Use only these categories: technical, delivery, payment, return, warranty, accessories,
product_advice, account_order, other.

Choose priority critical only for a safety risk: fire, smoke, sparks, electric shock, burning
smell, or a swollen battery. Anything that is merely urgent for the customer is high at most.

For each issue fill the slots object with details the customer stated:
- order_id: order number
- model: device model or product name
- serial_number: serial or IMEI number
- purchase_date: date of purchase
- amount: payment amount
- reason: reason for a return
- issue: short description of the malfunction

Critical rule: if a value is not stated explicitly in the message, set it to null. Never guess,
never infer, never reuse a value from another issue and never invent a plausible number. A made-up
serial number is far worse than a null one — the support team asks the customer for nulls."""

REPLY_INSTRUCTIONS = """You write concise, polite Russian replies for an electronics store support team.
Do not promise a refund, repair, compensation or any outcome that has not been approved: write that
the request has been accepted and is being processed. If the request is missing information, ask for
exactly the fields listed as missing, in one sentence. Never invent order numbers, dates or prices."""


def client() -> OpenAI:
    if not settings.yandex_api_key:
        raise RuntimeError("YANDEX_API_KEY is missing. Add it to the .env file.")
    if not settings.yandex_folder_id:
        raise RuntimeError(
            "YANDEX_CLOUD_FOLDER is missing. Add it to the .env file."
        )
    return OpenAI(
        api_key=settings.yandex_api_key,
        project=settings.yandex_folder_id,
        base_url=settings.yandex_base_url,
    )


def model_name() -> str:
    return f"gpt://{settings.yandex_folder_id}/{settings.yandex_model}"


def analyze_text(text: str) -> list[ExtractedIssue]:
    if settings.use_fake_llm:
        return fake_analyze(text)

    response = client().responses.parse(
        model=model_name(),
        instructions=ANALYZE_INSTRUCTIONS,
        input=text,
        text_format=IssueAnalysis,
    )
    if response.output_parsed is None:
        raise RuntimeError("The LLM did not return structured issue data.")
    return response.output_parsed.issues


EXTRACT_INSTRUCTIONS = """You extract specific field values from a customer's follow-up
message in a support chat. The support team asked for a list of fields; the customer has
just answered.

Fill a field only if its value is stated in this answer. If the customer did not give a
value, or wrote something like "не знаю" or "не помню", set that field to null. Never
guess and never invent a plausible number — a wrong serial number is worse than none.
Copy values exactly as the customer wrote them."""


def extract_slots(text: str, needed_fields: list[str]) -> IssueSlots:
    """Pull the requested fields out of the customer's answer.

    One call covers every field the whole request is waiting for; the caller then
    hands each value to the issues that asked for it.
    """
    if settings.use_fake_llm:
        return fake_extract_slots(text, needed_fields)

    response = client().responses.parse(
        model=model_name(),
        instructions=EXTRACT_INSTRUCTIONS,
        input=f"Fields the team asked for: {', '.join(needed_fields)}\nCustomer answer: {text}",
        text_format=IssueSlots,
    )
    if response.output_parsed is None:
        raise RuntimeError("The LLM did not return structured slot data.")
    return response.output_parsed


def draft_reply(
    title: str,
    description: str,
    category: str,
    slots: dict[str, str | None] | None = None,
    missing: list[str] | None = None,
) -> str:
    """Draft a reply for the operator to edit.

    The known and missing fields are passed in so the draft asks for exactly what
    the rules found to be absent, instead of the model's own guess at it.
    """
    slots = slots or {}
    missing = missing or []

    if settings.use_fake_llm:
        return fake_reply(title, category, missing)

    known = ", ".join(f"{key}={value}" for key, value in slots.items() if value) or "нет"
    gaps = ", ".join(missing) or "нет"
    response = client().responses.create(
        model=model_name(),
        instructions=REPLY_INSTRUCTIONS,
        input=(
            f"Issue title: {title}\nDescription: {description}\nCategory: {category}\n"
            f"Known fields: {known}\nMissing fields: {gaps}\n"
            "Write a ready-to-send customer reply in Russian."
        ),
    )
    if not response.output_text:
        raise RuntimeError("The LLM did not return a reply.")
    return response.output_text.strip()


__all__ = ["analyze_text", "extract_slots", "draft_reply", "IssueSlots"]
