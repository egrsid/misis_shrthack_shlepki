"""Pydantic contracts for HTTP and LLM data."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


Category = Literal[
    "technical",
    "delivery",
    "payment",
    "return",
    "warranty",
    "accessories",
    "product_advice",
    "account_order",
    "other",
]
Priority = Literal["critical", "high", "medium", "low"]
Status = Literal["new", "awaiting_info", "in_progress", "resolved", "closed"]


class AnalyzeRequest(BaseModel):
    user_id: int = Field(gt=0)
    text: str = Field(min_length=3, max_length=5000)


class IssueSlots(BaseModel):
    """Entities the LLM may extract from the message.

    Deliberately a fixed set of fields rather than a free-form dict: Structured
    Outputs needs a closed schema, and fixed keys are what the REQUIRED table
    checks against. A field is None whenever the customer did not state it.
    """

    order_id: str | None = None
    model: str | None = None
    serial_number: str | None = None
    purchase_date: str | None = None
    amount: str | None = None
    reason: str | None = None
    issue: str | None = None


# These models are used as the exact JSON contract for the LLM.
class ExtractedIssue(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=3, max_length=1000)
    category: Category
    priority: Priority
    slots: IssueSlots = Field(default_factory=IssueSlots)


class IssueAnalysis(BaseModel):
    issues: list[ExtractedIssue] = Field(min_length=1, max_length=10)


class IssueUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=200)
    description: str | None = Field(default=None, min_length=3, max_length=1000)
    category: Category | None = None
    priority: Priority | None = None
    status: Status | None = None
    # Merged into the stored slots; missing fields and status are recomputed.
    slots: dict[str, str | None] | None = None


class ReplyCreate(BaseModel):
    text: str = Field(min_length=1, max_length=5000)


class IssueOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    original_text: str
    title: str
    description: str
    category: Category
    priority: Priority
    status: Status
    slots: dict[str, str | None] = {}
    missing: list[str] = []
    generated_reply: str | None
    final_reply: str | None
    # Ties issues split out of the same customer message together, so the
    # operator sees "issue 1 of 3" instead of three unrelated tickets.
    request_id: str | None = None
    group_index: int = 1
    group_total: int = 1
    created_at: datetime
    updated_at: datetime


class AnalyzeResponse(BaseModel):
    """Everything Swift needs after one customer message."""

    request_id: str
    issues: list[IssueOut]
    # One message asking about every gap at once; None when nothing is missing.
    clarification: str | None = None


class GenerateReplyResponse(BaseModel):
    issue: IssueOut
    reply: str


class ReplyResponse(BaseModel):
    issue: IssueOut
    reply: str
