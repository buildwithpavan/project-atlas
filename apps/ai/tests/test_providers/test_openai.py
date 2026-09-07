from unittest.mock import MagicMock, patch

import pytest

from app.providers.openai import (
    AIServiceError,
    APIError,
    AuthenticationError,
    ConfigurationError,
    InvalidResponseError,
    RateLimitError,
    RefusalError,
    TimeoutError,
    analyze_ticket,
    SYSTEM_PROMPT,
)
from app.schemas import TicketAnalysisResponse


def _make_parsed_content(response_obj):
    """Create a mock content block with a parsed Pydantic model."""
    content_block = MagicMock()
    content_block.refusal = None
    content_block.parsed = response_obj
    return content_block


def _make_refusal_content(reason="I cannot analyze this"):
    """Create a mock content block representing a refusal."""
    content_block = MagicMock()
    content_block.refusal = reason
    content_block.parsed = None
    return content_block


def _make_response(content_blocks):
    """Create a mock OpenAI response with the given content blocks."""
    output_item = MagicMock()
    output_item.content = content_blocks
    response = MagicMock()
    response.output = [output_item]
    return response


MOCK_ANALYSIS = TicketAnalysisResponse(
    ticket_id="ignored",
    sentiment="negative",
    summary="Customer payment declined",
    category="billing",
    confidence=0.92,
    feature_request=False,
    bug_report=False,
    knowledge_gap=True,
)


class TestAnalyzeTicketSuccess:
    @patch("app.providers.openai.OpenAI")
    def test_returns_ticket_analysis_response(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_parsed_content(MOCK_ANALYSIS)]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            result = analyze_ticket("t-1", "Payment failed", "Declined")

        assert isinstance(result, TicketAnalysisResponse)
        assert result.ticket_id == "t-1"
        assert result.sentiment == "negative"
        assert result.category == "billing"
        assert result.confidence == 0.92
        assert result.knowledge_gap is True

    @patch("app.providers.openai.OpenAI")
    def test_passes_correct_model(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_parsed_content(MOCK_ANALYSIS)]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            analyze_ticket("t-1", "Subject", "Desc")

        call_kwargs = mock_client.responses.parse.call_args[1]
        assert call_kwargs["model"] == "gpt-5.6-luna"

    @patch("app.providers.openai.OpenAI")
    def test_passes_explicit_timeout(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_parsed_content(MOCK_ANALYSIS)]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            analyze_ticket("t-1", "Subject", "Desc")

        mock_openai_cls.assert_called_once_with(api_key="sk-test-key", timeout=25.0)

    @patch("app.providers.openai.OpenAI")
    def test_system_prompt_contains_required_instructions(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_parsed_content(MOCK_ANALYSIS)]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            analyze_ticket("t-1", "Subject", "Desc")

        call_kwargs = mock_client.responses.parse.call_args[1]
        messages = call_kwargs["input"]
        system_msg = next(m for m in messages if m["role"] == "system")
        assert "support ticket analyst" in system_msg["content"]
        assert "sentiment" in system_msg["content"]
        assert "knowledge_gap" in system_msg["content"]

    @patch("app.providers.openai.OpenAI")
    def test_user_prompt_format(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_parsed_content(MOCK_ANALYSIS)]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            analyze_ticket("t-1", "Payment failed", "My card was declined")

        call_kwargs = mock_client.responses.parse.call_args[1]
        messages = call_kwargs["input"]
        user_msg = next(m for m in messages if m["role"] == "user")
        assert "Subject: Payment failed" in user_msg["content"]
        assert "Description: My card was declined" in user_msg["content"]

    @patch("app.providers.openai.OpenAI")
    def test_requests_structured_output(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_parsed_content(MOCK_ANALYSIS)]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            analyze_ticket("t-1", "Subject", "Desc")

        call_kwargs = mock_client.responses.parse.call_args[1]
        assert call_kwargs["text_format"] is TicketAnalysisResponse


class TestAnalyzeTicketRefusal:
    @patch("app.providers.openai.OpenAI")
    def test_refusal_raises_refusal_error(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_client.responses.parse.return_value = _make_response(
            [_make_refusal_content("I cannot do this")]
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test-key"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(RefusalError):
                analyze_ticket("t-1", "Subject", "Desc")


class TestAnalyzeTicketErrors:
    def test_missing_api_key_raises_configuration_error(self):
        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = ""
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(ConfigurationError, match="OPENAI_API_KEY"):
                analyze_ticket("t-1", "Subject", "Desc")

    @patch("app.providers.openai.OpenAI")
    def test_auth_error_raises_authentication_error(self, mock_openai_cls):
        from openai import AuthenticationError as OpenAIAuthError

        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.headers = {}
        mock_client.responses.parse.side_effect = OpenAIAuthError(
            message="Invalid API key",
            response=mock_response,
            body=None,
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-invalid"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(AuthenticationError):
                analyze_ticket("t-1", "Subject", "Desc")

    @patch("app.providers.openai.OpenAI")
    def test_rate_limit_raises_rate_limit_error(self, mock_openai_cls):
        from openai import RateLimitError as OpenAIRateLimitError

        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.status_code = 429
        mock_response.headers = {}
        mock_client.responses.parse.side_effect = OpenAIRateLimitError(
            message="Rate limit exceeded",
            response=mock_response,
            body=None,
        )

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(RateLimitError):
                analyze_ticket("t-1", "Subject", "Desc")

    @patch("app.providers.openai.OpenAI")
    def test_timeout_raises_timeout_error(self, mock_openai_cls):
        from openai import APITimeoutError as OpenAITimeoutError

        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_request = MagicMock()
        mock_client.responses.parse.side_effect = OpenAITimeoutError(request=mock_request)

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(TimeoutError):
                analyze_ticket("t-1", "Subject", "Desc")

    @patch("app.providers.openai.OpenAI")
    def test_connection_error_raises_api_error(self, mock_openai_cls):
        from openai import APIConnectionError as OpenAIConnectionError

        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client
        mock_request = MagicMock()
        mock_client.responses.parse.side_effect = OpenAIConnectionError(request=mock_request)

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(APIError):
                analyze_ticket("t-1", "Subject", "Desc")

    @patch("app.providers.openai.OpenAI")
    def test_empty_output_raises_invalid_response_error(self, mock_openai_cls):
        mock_client = MagicMock()
        mock_openai_cls.return_value = mock_client

        # Response with no parsed content
        content_block = MagicMock()
        content_block.refusal = None
        content_block.parsed = None
        mock_client.responses.parse.return_value = _make_response([content_block])

        with patch("app.providers.openai.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            mock_settings.openai_model = "gpt-5.6-luna"
            mock_settings.openai_timeout = 25.0
            with pytest.raises(InvalidResponseError):
                analyze_ticket("t-1", "Subject", "Desc")


class TestErrorHierarchy:
    def test_all_errors_inherit_from_ai_service_error(self):
        assert issubclass(ConfigurationError, AIServiceError)
        assert issubclass(AuthenticationError, AIServiceError)
        assert issubclass(RateLimitError, AIServiceError)
        assert issubclass(TimeoutError, AIServiceError)
        assert issubclass(APIError, AIServiceError)
        assert issubclass(InvalidResponseError, AIServiceError)
        assert issubclass(RefusalError, AIServiceError)


class TestSystemPrompt:
    def test_prompt_includes_all_sentiments(self):
        assert "positive" in SYSTEM_PROMPT
        assert "negative" in SYSTEM_PROMPT
        assert "neutral" in SYSTEM_PROMPT
        assert "mixed" in SYSTEM_PROMPT

    def test_prompt_includes_all_categories(self):
        assert "billing" in SYSTEM_PROMPT
        assert "technical_issue" in SYSTEM_PROMPT
        assert "feature_request" in SYSTEM_PROMPT
        assert "account" in SYSTEM_PROMPT
        assert "onboarding" in SYSTEM_PROMPT
        assert "integrations" in SYSTEM_PROMPT
        assert "performance" in SYSTEM_PROMPT
        assert "general" in SYSTEM_PROMPT

    def test_prompt_includes_knowledge_gap(self):
        assert "knowledge_gap" in SYSTEM_PROMPT
