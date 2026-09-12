"""Deterministic triage rules.

The LLM understands text; this module decides. Every function here is pure and
testable, so the same customer message always produces the same verdict and any
demo question ("why did it ask for the serial number?") has a code-level answer.
"""

from __future__ import annotations

# Fields that must be known before an issue of a given category can be accepted.
REQUIRED: dict[str, list[str]] = {
    "warranty": ["order_id", "model", "serial_number", "purchase_date"],
    "return": ["order_id", "model", "reason"],
    "payment": ["order_id", "amount"],
    "delivery": ["order_id"],
    "technical": ["model", "issue"],
    "accessories": ["model"],
    "product_advice": [],
    "account_order": ["order_id"],
    "other": [],
}

# Accusative case, so the labels drop straight into "Укажите, пожалуйста: ...".
SLOT_LABELS: dict[str, str] = {
    "order_id": "номер заказа",
    "model": "модель устройства",
    "serial_number": "серийный номер",
    "purchase_date": "дату покупки",
    "amount": "сумму платежа",
    "reason": "причину возврата",
    "issue": "что именно происходит с устройством",
}

# Prefix that tells the customer which of their problems the question is about.
CATEGORY_PHRASES: dict[str, str] = {
    "warranty": "Для гарантийного обращения",
    "return": "Для оформления возврата",
    "payment": "По вопросу оплаты",
    "delivery": "По вопросу доставки",
    "technical": "По технической проблеме",
    "accessories": "По вопросу аксессуаров",
    "account_order": "По вашему заказу",
    "product_advice": "Чтобы подобрать товар",
    "other": "По вашему обращению",
}

# The LLM is told to return null for anything the customer did not state, but a
# model under load still slips in filler. Treat these as "not provided".
_EMPTY_VALUES = {
    "",
    "-",
    "—",
    "n/a",
    "na",
    "null",
    "none",
    "не указано",
    "не указан",
    "не указана",
    "неизвестно",
    "нет данных",
    "отсутствует",
}


def clean_slot(value: str | None) -> str | None:
    """Normalise one extracted value, collapsing LLM filler to None."""
    if value is None:
        return None
    cleaned = value.strip()
    if cleaned.lower() in _EMPTY_VALUES:
        return None
    return cleaned or None


def clean_slots(slots: dict[str, str | None]) -> dict[str, str | None]:
    return {key: clean_slot(value) for key, value in slots.items()}


def missing_fields(category: str, slots: dict[str, str | None]) -> list[str]:
    """Fields required by the category that the customer has not provided."""
    return [field for field in REQUIRED.get(category, []) if not slots.get(field)]


# An issue in this status has not reached the operator yet: the chat is still
# collecting the required fields from the customer.
COLLECTING = "collecting"

# Statuses the operator owns. Re-running triage must never overwrite them, and
# must never pull an already submitted issue back out of the operator's feed.
OPERATOR_STATUSES = frozenset({"awaiting_info", "in_progress", "resolved", "closed"})


def status_for(missing: list[str]) -> str:
    """An incomplete issue is not sent to the operator, it is asked about first."""
    return COLLECTING if missing else "new"


def status_after_edit(current: str, missing: list[str]) -> str:
    """Status after slots or category changed.

    Only an issue that is still being collected can change side: once it has been
    submitted, a new gap is shown to the operator but never hides the issue again.
    """
    if current in OPERATOR_STATUSES:
        return current
    if current == COLLECTING:
        return status_for(missing)
    return current


def visible_slots(category: str, slots: dict[str, str | None]) -> dict[str, str | None]:
    """Slots worth showing an operator: required by the category, plus anything found.

    Without this filter every issue would display all seven fields, most of them
    null and irrelevant, and the operator would stop reading the block.
    """
    keys = list(REQUIRED.get(category, []))
    for key, value in slots.items():
        if value and key not in keys:
            keys.append(key)
    return {key: slots.get(key) for key in keys}


def _join_russian(labels: list[str]) -> str:
    if len(labels) == 1:
        return labels[0]
    return ", ".join(labels[:-1]) + " и " + labels[-1]


def clarification_text(issues: list[tuple[str, list[str]]]) -> str | None:
    """Build one clarifying message covering every gap in the whole request.

    `issues` is (category, missing) per extracted issue. Asking once about
    everything is the point: three separate follow-up messages for one customer
    message would be worse than what the operator does today.
    """
    lines: list[str] = []
    seen: set[tuple[str, tuple[str, ...]]] = set()

    for category, missing in issues:
        if not missing:
            continue
        key = (category, tuple(missing))
        if key in seen:
            continue
        seen.add(key)

        labels = [SLOT_LABELS.get(field, field) for field in missing]
        prefix = CATEGORY_PHRASES.get(category, CATEGORY_PHRASES["other"])
        lines.append(f"{prefix} укажите, пожалуйста: {_join_russian(labels)}.")

    if not lines:
        return None
    return "\n".join(lines)
