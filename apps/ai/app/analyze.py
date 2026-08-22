from app.providers.openai import analyze_ticket
from app.schemas import TicketAnalysisRequest, TicketAnalysisResponse


def perform_analysis(request: TicketAnalysisRequest) -> TicketAnalysisResponse:
    """Orchestrate ticket analysis through the configured provider."""
    return analyze_ticket(
        ticket_id=request.ticket_id,
        subject=request.subject,
        description=request.description,
    )
