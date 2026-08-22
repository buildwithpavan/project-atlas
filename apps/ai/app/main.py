import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.analyze import perform_analysis
from app.config import settings
from app.providers.openai import (
    AIServiceError,
    AuthenticationError,
    ConfigurationError,
    InvalidResponseError,
    ProviderError,
    RateLimitError,
    RefusalError,
    TimeoutError,
)
from app.schemas import (
    HealthResponse,
    TicketAnalysisRequest,
    TicketAnalysisResponse,
)

logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name, version="0.2.0")


@app.exception_handler(ConfigurationError)
async def configuration_error_handler(request: Request, exc: ConfigurationError) -> JSONResponse:
    return JSONResponse(status_code=500, content={"error": "ai_configuration_error", "detail": str(exc)})


@app.exception_handler(AuthenticationError)
async def authentication_error_handler(request: Request, exc: AuthenticationError) -> JSONResponse:
    return JSONResponse(status_code=503, content={"error": "provider_auth_error", "detail": "AI provider authentication failed"})


@app.exception_handler(RateLimitError)
async def rate_limit_error_handler(request: Request, exc: RateLimitError) -> JSONResponse:
    return JSONResponse(status_code=503, content={"error": "provider_rate_limited", "detail": "AI provider rate limit exceeded"})


@app.exception_handler(TimeoutError)
async def timeout_error_handler(request: Request, exc: TimeoutError) -> JSONResponse:
    return JSONResponse(status_code=503, content={"error": "provider_timeout", "detail": "AI provider request timed out"})


@app.exception_handler(RefusalError)
async def refusal_error_handler(request: Request, exc: RefusalError) -> JSONResponse:
    return JSONResponse(status_code=502, content={"error": "analysis_refused", "detail": "Model refused to analyze the content"})


@app.exception_handler(InvalidResponseError)
async def invalid_response_error_handler(request: Request, exc: InvalidResponseError) -> JSONResponse:
    return JSONResponse(status_code=502, content={"error": "malformed_response", "detail": "Invalid response from AI provider"})


@app.exception_handler(ProviderError)
async def provider_error_handler(request: Request, exc: ProviderError) -> JSONResponse:
    return JSONResponse(status_code=502, content={"error": "provider_error", "detail": "AI provider error"})


@app.exception_handler(AIServiceError)
async def ai_service_error_handler(request: Request, exc: AIServiceError) -> JSONResponse:
    return JSONResponse(status_code=500, content={"error": "ai_service_error", "detail": "Unexpected AI service error"})


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="atlas-ai")


@app.post("/v1/analyze/ticket", response_model=TicketAnalysisResponse)
def analyze_ticket(request: TicketAnalysisRequest) -> TicketAnalysisResponse:
    return perform_analysis(request)
