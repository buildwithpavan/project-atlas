from typing import Literal

from pydantic import BaseModel, Field

Sentiment = Literal["positive", "negative", "neutral", "mixed"]
Category = Literal[
    "billing",
    "technical_issue",
    "feature_request",
    "account",
    "onboarding",
    "integrations",
    "performance",
    "general",
]


class HealthResponse(BaseModel):
    status: str
    service: str


class TicketAnalysisRequest(BaseModel):
    ticket_id: str
    subject: str
    description: str


class TicketAnalysisResponse(BaseModel):
    ticket_id: str
    sentiment: Sentiment
    summary: str
    category: Category
    confidence: float = Field(ge=0.0, le=1.0)
    feature_request: bool
    bug_report: bool
    knowledge_gap: bool
