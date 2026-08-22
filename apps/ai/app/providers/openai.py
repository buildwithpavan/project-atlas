import logging
import time

from openai import OpenAI
from openai import AuthenticationError as OpenAIAuthError
from openai import RateLimitError as OpenAIRateLimitError
from openai import APITimeoutError as OpenAITimeoutError
from openai import APIConnectionError as OpenAIConnectionError
from openai import APIStatusError as OpenAIStatusError

from app.config import settings
from app.schemas import TicketAnalysisResponse

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """\
You are a support ticket analyst. Analyze the given customer support ticket and extract structured insights.

For each ticket, determine:
- sentiment: The overall customer sentiment (positive, negative, neutral, or mixed)
- summary: A concise 1-2 sentence summary of the ticket's core issue or request
- category: Exactly one of: billing, technical_issue, feature_request, account, onboarding, integrations, performance, general
- confidence: Your confidence in this analysis from 0.0 to 1.0
- feature_request: Whether this ticket contains or implies a feature request
- bug_report: Whether this ticket reports a bug or defect
- knowledge_gap: Whether this ticket reveals a gap in documentation or user knowledge

Be precise and objective. Base your analysis only on the ticket content provided."""


class AIServiceError(Exception):
    """Base error for AI service failures."""


class ConfigurationError(AIServiceError):
    """Missing or invalid configuration."""


class ProviderError(AIServiceError):
    """Base for provider-specific errors."""


class AuthenticationError(ProviderError):
    """OpenAI authentication failure."""


class RateLimitError(ProviderError):
    """OpenAI rate limit exceeded."""


class TimeoutError(ProviderError):
    """OpenAI request timeout."""


class APIError(ProviderError):
    """OpenAI API/server failure."""


class InvalidResponseError(AIServiceError):
    """Model returned an unparseable or invalid response."""


class RefusalError(AIServiceError):
    """Model refused to analyze the content."""


def analyze_ticket(ticket_id: str, subject: str, description: str) -> TicketAnalysisResponse:
    """Call OpenAI to analyze a support ticket and return structured analysis."""
    if not settings.openai_api_key:
        raise ConfigurationError("OPENAI_API_KEY is not configured")

    client = OpenAI(api_key=settings.openai_api_key)

    user_content = f"Subject: {subject}\nDescription: {description}"

    start_time = time.monotonic()
    try:
        response = client.responses.parse(
            model=settings.openai_model,
            input=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            text_format=TicketAnalysisResponse,
        )
    except OpenAIAuthError as e:
        logger.error("ticket_id=%s provider=openai error=auth_failure", ticket_id)
        raise AuthenticationError("OpenAI authentication failed") from e
    except OpenAIRateLimitError as e:
        logger.warning("ticket_id=%s provider=openai error=rate_limited", ticket_id)
        raise RateLimitError("OpenAI rate limit exceeded") from e
    except OpenAITimeoutError as e:
        logger.warning("ticket_id=%s provider=openai error=timeout", ticket_id)
        raise TimeoutError("OpenAI request timed out") from e
    except (OpenAIConnectionError, OpenAIStatusError) as e:
        logger.error("ticket_id=%s provider=openai error=api_error", ticket_id)
        raise APIError("OpenAI API error") from e

    duration_ms = int((time.monotonic() - start_time) * 1000)

    # Extract parsed content, handling refusals
    output_content = None
    for item in response.output:
        for content_block in item.content:
            if hasattr(content_block, "refusal") and content_block.refusal:
                logger.warning("ticket_id=%s provider=openai error=refusal", ticket_id)
                raise RefusalError("Model refused to analyze the ticket")
            if hasattr(content_block, "parsed") and content_block.parsed is not None:
                output_content = content_block.parsed
                break
        if output_content is not None:
            break

    if output_content is None:
        logger.error("ticket_id=%s provider=openai error=invalid_response", ticket_id)
        raise InvalidResponseError("No valid structured response from model")

    logger.info(
        "ticket_id=%s provider=openai model=%s duration_ms=%d status=success",
        ticket_id,
        settings.openai_model,
        duration_ms,
    )

    # The SDK returns a TicketAnalysisResponse instance via structured outputs.
    # Override ticket_id to match the request (model doesn't know it).
    return TicketAnalysisResponse(
        ticket_id=ticket_id,
        sentiment=output_content.sentiment,
        summary=output_content.summary,
        category=output_content.category,
        confidence=output_content.confidence,
        feature_request=output_content.feature_request,
        bug_report=output_content.bug_report,
        knowledge_gap=output_content.knowledge_gap,
    )
