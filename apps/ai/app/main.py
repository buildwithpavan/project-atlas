from fastapi import FastAPI

from app.config import settings
from app.schemas import (
    HealthResponse,
    TicketAnalysisRequest,
    TicketAnalysisResponse,
)

app = FastAPI(title=settings.app_name, version="0.1.0")


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="atlas-ai")


@app.post("/v1/analyze/ticket", response_model=TicketAnalysisResponse)
def analyze_ticket(request: TicketAnalysisRequest) -> TicketAnalysisResponse:
    return TicketAnalysisResponse(
        ticket_id=request.ticket_id,
        sentiment="neutral",
        summary="AI analysis placeholder.",
        category="general",
        confidence=0.0,
        feature_request=False,
        bug_report=False,
    )
