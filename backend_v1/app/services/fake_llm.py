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
