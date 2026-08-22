from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    service: str


class TicketAnalysisRequest(BaseModel):
    ticket_id: str
    subject: str
    description: str


class TicketAnalysisResponse(BaseModel):
    ticket_id: str
    sentiment: str
    summary: str
    category: str
    confidence: float = Field(ge=0.0, le=1.0)
    feature_request: bool
    bug_report: bool
