# Voceive AI Service

FastAPI service that provides AI-powered ticket analysis using OpenAI's Responses API with structured outputs.

## Architecture

```
Rails (app container)
  → AI_PROVIDER=atlas
  → Ai::Providers::Atlas
  → Ai::Client (HTTP)
  → http://ai:8000/v1/analyze/ticket
  → FastAPI
  → OpenAI Responses API (structured output)
  → Pydantic-validated response
  → JSON back to Rails
  → AiAnalysis record persisted
```

In Voceive mode, Rails delegates AI calls to this service over HTTP. The FastAPI service owns the OpenAI integration and returns structured, validated responses.

## Environment Variables

### FastAPI Service (ai container)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | — | OpenAI API key. Service starts without it (health checks pass) but analysis requests fail. |
| `OPENAI_MODEL` | No | `gpt-5.6-luna` | OpenAI model for structured outputs. |
| `ENVIRONMENT` | No | `development` | Runtime environment identifier. |

### Rails (app container)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AI_PROVIDER` | No | `openai` | Set to `atlas` to route through FastAPI. |
| `AI_SERVICE_URL` | No | `http://ai:8000` | FastAPI service base URL. |
| `AI_SERVICE_TIMEOUT` | No | `10` | HTTP timeout in seconds. |

## Provider Modes

### `AI_PROVIDER=atlas` (recommended for Docker development)

Rails → FastAPI → OpenAI. Only the FastAPI container needs `OPENAI_API_KEY`.

### `AI_PROVIDER=openai` (fallback / code default)

Rails → OpenAI directly via the Ruby SDK. Rails needs `OPENAI_API_KEY` in its own environment.

**Important:** The Rails code default remains `"openai"` as a safe fallback. The Docker Compose file explicitly sets `AI_PROVIDER=atlas` for local development.

## Local Development

### Start the service

```bash
docker compose up -d ai
```

### Verify health

```bash
curl http://localhost:8000/health
# or from another container:
curl http://ai:8000/health
```

Expected: `{"status":"ok","service":"voceive-ai"}`

### Inject the API key

The `ai` service reads `OPENAI_API_KEY` from the host environment via Docker Compose:

```bash
# Option 1: Export before docker compose up
export OPENAI_API_KEY=sk-...
docker compose up -d ai

# Option 2: Source from .env
set -a && source apps/api/.env && set +a
docker compose up -d --force-recreate ai
```

### Rebuild after code changes

```bash
docker compose up -d --build --force-recreate ai
```

## Rollback to Direct OpenAI

If the FastAPI service is unavailable or you need to bypass it:

```bash
# Set in shell before running Rails:
AI_PROVIDER=openai OPENAI_API_KEY=sk-... bundle exec rails runner '...'

# Or in docker-compose.yml, change:
#   AI_PROVIDER: atlas
# to:
#   AI_PROVIDER: openai
# and add OPENAI_API_KEY to the app service environment.
```

No code changes are required to switch providers.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check (no API key required) |
| POST | `/v1/analyze/ticket` | Analyze a support ticket |

### POST /v1/analyze/ticket

Request:
```json
{
  "ticket_id": "uuid",
  "subject": "Ticket subject",
  "description": "Ticket description"
}
```

Response:
```json
{
  "ticket_id": "uuid",
  "sentiment": "negative",
  "summary": "Concise summary of the issue.",
  "category": "billing",
  "confidence": 0.95,
  "feature_request": false,
  "bug_report": true,
  "knowledge_gap": false
}
```

## Running Tests

```bash
cd apps/ai
source .venv/bin/activate
python -m pytest tests/ -v
```
