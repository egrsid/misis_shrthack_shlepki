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
Status = Literal["new", "in_progress", "resolved", "closed"]


class AnalyzeRequest(BaseModel):
    user_id: int = Field(gt=0)
    text: str = Field(min_length=3, max_length=5000)


# These two models are used as the exact JSON contract for the LLM.
class ExtractedIssue(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=3, max_length=1000)
    category: Category
    priority: Priority


class IssueAnalysis(BaseModel):
    issues: list[ExtractedIssue] = Field(min_length=1, max_length=10)


class IssueUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=200)
    description: str | None = Field(default=None, min_length=3, max_length=1000)
    category: Category | None = None
    priority: Priority | None = None
    status: Status | None = None


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
    generated_reply: str | None
    final_reply: str | None
    created_at: datetime
    updated_at: datetime


class GenerateReplyResponse(BaseModel):
    issue: IssueOut
    reply: str


class ReplyResponse(BaseModel):
    issue: IssueOut
    reply: str
