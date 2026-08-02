# AI Design

## Goals

- Cluster tickets
- Summarize tickets
- Detect sentiment
- Extract feature requests
- Identify knowledge gaps

---

## AI Pipeline

CSV Upload

↓

Rails

↓

Sidekiq

↓

FastAPI

↓

LLM

↓

JSON Response

↓

Rails Database

---

## Models

Phase 1

- GPT-5 or Claude

Future

- Local models
- Multi-model support

---

## Prompt Strategy

System Prompt

↓

Ticket Batch

↓

JSON Output

---

## Embeddings

Future Phase

- pgvector

- Semantic search

- Similar tickets

---

## Future AI Agents

- Categorization Agent

- Report Agent

- Knowledge Agent

- Trend Agent