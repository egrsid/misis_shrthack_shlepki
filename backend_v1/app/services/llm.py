from openai import OpenAI

from app.core.config import settings
from app.schemas.issue import ExtractedIssue, IssueAnalysis


ANALYZE_INSTRUCTIONS = """You are an AI triage assistant for an electronics store support team.
Split one customer message into separate, independent support issues. Do not invent facts.
Use only these categories: technical, delivery, payment, return, warranty, accessories,
product_advice, account_order, other. Choose critical only for safety risks such as fire,
smoke, sparks, electric shock, or a swollen battery. Use Russian because the customer writes
in Russian. Return every customer concern as a separate issue."""


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
    response = client().responses.parse(
        model=model_name(),
        instructions=ANALYZE_INSTRUCTIONS,
        input=text,
        text_format=IssueAnalysis,
    )
    if response.output_parsed is None:
        raise RuntimeError("The LLM did not return structured issue data.")
    return response.output_parsed.issues


def draft_reply(title: str, description: str, category: str) -> str:
    response = client().responses.create(
        model=model_name(),
        instructions=(
            "You write concise, polite Russian replies for an electronics store support team. "
            "Do not promise a refund, repair, or outcome that has not been approved. "
            "Ask at most one useful clarifying question."
        ),
        input=(
            f"Issue title: {title}\nDescription: {description}\nCategory: {category}\n"
            "Write a ready-to-send customer reply."
        ),
    )
    if not response.output_text:
        raise RuntimeError("The LLM did not return a reply.")
    return response.output_text.strip()
