"""Offline stand-in for Yandex AI Studio, enabled with USE_FAKE_LLM=1.

Two uses: running the whole flow without an API key, and surviving a dead network
during the defence. It is keyword matching, not understanding — the real value of
the project is that every decision after the split is made by the rules in
app/core/triage.py, and those run identically on this output.
"""

from __future__ import annotations

import re

from app.schemas.issue import ExtractedIssue, IssueSlots

# (category, priority, title, keywords)
_RULES: list[tuple[str, str, str, tuple[str, ...]]] = [
    ("warranty", "high", "Гарантийное обращение", ("гарант", "ремонт по гарантии")),
    ("return", "medium", "Запрос на возврат", ("возврат", "вернуть", "отказ от товара")),
    ("delivery", "medium", "Вопрос по доставке", ("доставк", "не приехал", "не привезли", "где заказ", "посылк", "курьер")),
    ("payment", "high", "Вопрос по оплате", ("оплат", "списал", "деньги", "платеж", "платёж", "счет", "счёт")),
    ("technical", "high", "Техническая неисправность", ("греет", "нагрев", "не включ", "не работает", "выключа", "зависа", "сломал", "перезагруж", "трещин")),
    ("accessories", "low", "Вопрос по аксессуарам", ("чехол", "аксессуар", "зарядк", "кабель", "адаптер", "наушник")),
    ("product_advice", "low", "Подбор товара", ("посовет", "выбрать", "подобрать", "что лучше", "какой лучше")),
    ("account_order", "medium", "Вопрос по аккаунту или заказу", ("аккаунт", "личный кабинет", "пароль", "войти")),
    ("other", "medium", "Обращение в поддержку", ("не отвеча", "жалоб", "сколько ждать", "оператор")),
]

_SAFETY_WORDS = ("дым", "загорел", "возгоран", "искр", "вздул", "ударил ток", "горел", "запах гари")

_DEVICE_WORDS = {
    "ноутбук": "ноутбук",
    "смартфон": "смартфон",
    "телефон": "телефон",
    "планшет": "планшет",
    "телевизор": "телевизор",
    "часы": "умные часы",
    "наушники": "наушники",
    "колонк": "колонка",
    "приставк": "игровая приставка",
}


def _split_sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+|\n+", text)
    return [part.strip() for part in parts if part.strip()]


def _order_id(text: str) -> str | None:
    match = re.search(r"(?:заказ\w*|order)\D{0,10}(\d{3,})", text, re.IGNORECASE)
    return match.group(1) if match else None


def _model(text: str) -> str | None:
    lowered = text.lower()
    for needle, label in _DEVICE_WORDS.items():
        if needle in lowered:
            return label
    return None


def _serial(text: str) -> str | None:
    match = re.search(
        r"(?:серийн\w*|s/n|imei)\D{0,10}([A-Za-z0-9-]{5,})", text, re.IGNORECASE
    )
    return match.group(1) if match else None


def _amount(text: str) -> str | None:
    match = re.search(r"(\d[\d\s]{2,})\s*(?:₽|руб)", text, re.IGNORECASE)
    return match.group(1).strip() if match else None


def fake_analyze(text: str) -> list[ExtractedIssue]:
    sentences = _split_sentences(text) or [text.strip()]
    is_unsafe = any(word in text.lower() for word in _SAFETY_WORDS)

    found: dict[str, ExtractedIssue] = {}
    for sentence in sentences:
        lowered = sentence.lower()
        for category, priority, title, keywords in _RULES:
            if not any(keyword in lowered for keyword in keywords):
                continue
            if category in found:
                continue
            # Slots are filled only from the sentence that produced the issue, so
            # an order number in one complaint never leaks into another.
            found[category] = ExtractedIssue(
                title=title,
                description=sentence,
                category=category,
                priority="critical" if is_unsafe and category == "technical" else priority,
                slots=IssueSlots(
                    order_id=_order_id(sentence),
                    model=_model(sentence),
                    serial_number=_serial(sentence),
                    purchase_date=None,
                    amount=_amount(sentence),
                    reason=None,
                    issue=sentence if category == "technical" else None,
                ),
            )
            break

    if not found:
        stripped = text.strip()
        return [
            ExtractedIssue(
                title="Обращение в поддержку",
                description=stripped,
                category="other",
                priority="medium",
                slots=IssueSlots(),
            )
        ]
    return list(found.values())


_DATE_PATTERN = r"(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"


def fake_extract_slots(text: str, needed_fields: list[str]) -> IssueSlots:
    """Offline version of the follow-up extraction.

    Only fields the team actually asked for are filled, and only from patterns
    found in this answer — the same "never guess" rule the real prompt enforces.
    """
    wanted = set(needed_fields)
    values: dict[str, str | None] = {}

    if "order_id" in wanted:
        match = re.search(r"(?:заказ\w*|order)\D{0,10}(\d{3,})", text, re.IGNORECASE)
        values["order_id"] = match.group(1) if match else _bare_number(text)
    if "serial_number" in wanted:
        # A serial is the token that mixes letters and digits ("SN-4481-XZ"), taken
        # whole. Matching a "серийный номер" label instead would clip the prefix,
        # and a plain number is an order id, not a serial.
        values["serial_number"] = next(
            (
                token
                for token in re.findall(r"[A-Za-z0-9][A-Za-z0-9-]{3,}", text)
                if any(c.isalpha() for c in token) and any(c.isdigit() for c in token)
            ),
            None,
        )
    if "purchase_date" in wanted:
        match = re.search(_DATE_PATTERN, text)
        values["purchase_date"] = match.group(1) if match else None
    if "model" in wanted:
        values["model"] = _model(text)
    if "amount" in wanted:
        values["amount"] = _amount(text)
    if "reason" in wanted:
        # No pattern for a free-form reason: take the answer itself when it is short.
        stripped = text.strip()
        values["reason"] = stripped if 3 <= len(stripped) <= 200 else None
    if "issue" in wanted:
        stripped = text.strip()
        values["issue"] = stripped if 3 <= len(stripped) <= 200 else None

    return IssueSlots(**values)


def _bare_number(text: str) -> str | None:
    """A number on its own, for answers like "8823"."""
    match = re.fullmatch(r"\s*(\d{3,})\s*", text)
    return match.group(1) if match else None


def fake_reply(title: str, category: str, missing: list[str]) -> str:
    from app.core.triage import SLOT_LABELS

    opening = f"Здравствуйте! Мы приняли ваше обращение «{title}» в работу."
    if not missing:
        return f"{opening} Специалист свяжется с вами в ближайшее время."
    labels = ", ".join(SLOT_LABELS.get(field, field) for field in missing)
    return (
        f"{opening} Чтобы продолжить, укажите, пожалуйста: {labels}. "
        "Как только получим данные, сразу вернёмся с решением."
    )
