from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

VALID_PAYLOAD = {
    "ticket_id": "ticket-123",
    "subject": "Payment failed",
    "description": "My payment was declined.",
}


def test_analyze_ticket_returns_200():
    response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
    assert response.status_code == 200


def test_analyze_ticket_response_contract():
    response = client.post("/v1/analyze/ticket", json=VALID_PAYLOAD)
    data = response.json()

    assert data["ticket_id"] == "ticket-123"
    assert data["sentiment"] == "neutral"
    assert data["category"] == "general"
    assert 0.0 <= data["confidence"] <= 1.0
    assert data["feature_request"] is False
    assert data["bug_report"] is False


def test_analyze_ticket_missing_fields():
    response = client.post("/v1/analyze/ticket", json={"ticket_id": "t-1"})
    assert response.status_code == 422


def test_analyze_ticket_echoes_ticket_id():
    payload = {
        "ticket_id": "ticket-999",
        "subject": "Test subject",
        "description": "Test description",
    }
    response = client.post("/v1/analyze/ticket", json=payload)
    data = response.json()
    assert data["ticket_id"] == "ticket-999"
