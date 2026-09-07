from unittest.mock import patch, MagicMock

from fastapi.testclient import TestClient

from app.main import app
from app.providers.openai import (
    AuthenticationError,
    ConfigurationError,
    InvalidResponseError,
    RateLimitError,
    RefusalError,
    TimeoutError,
    APIError,
)
from app.schemas import TicketAnalysisResponse

client = TestClient(app)

VALID_PAYLOAD = {
    "ticket_id": "ticket-123",
    "subject": "Payment failed",
    "description": "My payment was declined.",
}

MOCK_RESPONSE = TicketAnalysisResponse(
    ticket_id="ticket-123",
    sentiment="negative",
    summary="Customer reports payment was declined.",
    category="billing",
    confidence=0.92,
    feature_request=False,
    bug_report=False,
    knowledge_gap=False,
)


def _mock_analysis(*args, **kwargs):
    return MOCK_RESPONSE


class TestAnalyzeTicketSuccess:
    def test_returns_200(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 200

    def test_response_contains_all_fields(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        data = response.json()
        assert "ticket_id" in data
        assert "sentiment" in data
        assert "summary" in data
        assert "category" in data
        assert "confidence" in data
        assert "feature_request" in data
        assert "bug_report" in data
        assert "knowledge_gap" in data

    def test_ticket_id_preserved(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.json()["ticket_id"] == "ticket-123"

    def test_valid_sentiment(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.json()["sentiment"] in ["positive", "negative", "neutral", "mixed"]

    def test_valid_category(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.json()["category"] in [
            "billing", "technical_issue", "feature_request", "account",
            "onboarding", "integrations", "performance", "general",
        ]

    def test_confidence_range(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        confidence = response.json()["confidence"]
        assert 0.0 <= confidence <= 1.0

    def test_knowledge_gap_present(self):
        with patch("app.analyze.analyze_ticket", side_effect=_mock_analysis):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert "knowledge_gap" in response.json()
        assert isinstance(response.json()["knowledge_gap"], bool)


class TestAnalyzeTicketValidation:
    def test_missing_fields_returns_422(self):
        response = client.post("/v1/analyze/ticket", json={"ticket_id": "t-1"})
        assert response.status_code == 422

    def test_empty_body_returns_422(self):
        response = client.post("/v1/analyze/ticket", json={})
        assert response.status_code == 422


class TestAnalyzeTicketErrors:
    def test_configuration_error_returns_500(self):
        with patch("app.analyze.analyze_ticket", side_effect=ConfigurationError("OPENAI_API_KEY is not configured")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 500
        assert response.json()["error"] == "ai_configuration_error"

    def test_authentication_error_returns_503(self):
        with patch("app.analyze.analyze_ticket", side_effect=AuthenticationError("auth failed")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 503
        assert response.json()["error"] == "provider_auth_error"

    def test_rate_limit_returns_503(self):
        with patch("app.analyze.analyze_ticket", side_effect=RateLimitError("rate limited")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 503
        assert response.json()["error"] == "provider_rate_limited"

    def test_timeout_returns_503(self):
        with patch("app.analyze.analyze_ticket", side_effect=TimeoutError("timed out")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 503
        assert response.json()["error"] == "provider_timeout"

    def test_api_error_returns_502(self):
        with patch("app.analyze.analyze_ticket", side_effect=APIError("server error")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 502
        assert response.json()["error"] == "provider_error"

    def test_invalid_response_returns_502(self):
        with patch("app.analyze.analyze_ticket", side_effect=InvalidResponseError("bad response")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 502
        assert response.json()["error"] == "malformed_response"

    def test_refusal_returns_502(self):
        with patch("app.analyze.analyze_ticket", side_effect=RefusalError("refused")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        assert response.status_code == 502
        assert response.json()["error"] == "analysis_refused"

    def test_error_response_does_not_leak_details(self):
        with patch("app.analyze.analyze_ticket", side_effect=AuthenticationError("sk-secret-key-123 is invalid")):
            response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
        body = response.json()
        assert "sk-secret" not in body.get("detail", "")
