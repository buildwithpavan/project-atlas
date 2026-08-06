# Project Atlas

> AI-native Customer Support Intelligence Platform built as a production-grade reference implementation using Ruby on Rails, FastAPI, Vue.js, Docker, Kubernetes, Terraform, and modern AI engineering practices.

---

## Vision

Project Atlas transforms customer support data into actionable business intelligence.

Rather than acting as a ticketing system, Atlas analyzes customer support interactions to help organizations understand:

- Customer pain points
- Recurring issues
- Feature requests
- Customer sentiment
- Product trends
- AI-generated executive summaries
- Knowledge base improvement opportunities

The goal is to demonstrate how to build a modern AI-native SaaS platform using production-quality engineering practices.

---

# Project Goals

- Build a production-grade SaaS platform
- Learn modern Ruby on Rails architecture
- Apply Domain-Driven Design (DDD)
- Build AI-powered business workflows
- Gain hands-on experience with Docker, Kubernetes, and Terraform
- Demonstrate production engineering practices
- Create an AI-agent-friendly codebase

---

# Technology Stack

## Backend

- Ruby on Rails 8
- PostgreSQL
- Redis
- Sidekiq

## Frontend

- Vue 3
- TypeScript
- Tailwind CSS

## AI

- Python FastAPI
- LangGraph
- OpenAI
- Anthropic (planned)

## Infrastructure

- Docker
- Kubernetes (planned)
- Terraform (planned)
- GitHub Actions

---

# Architecture

```
                Vue 3 Frontend
                        │
                 REST API (Rails)
                        │
        ┌───────────────┼───────────────┐
        │               │               │
 PostgreSQL         Redis         Sidekiq
        │                               │
        └───────────────┬───────────────┘
                        │
                 FastAPI AI Service
                        │
              OpenAI / Anthropic
```

---

# Engineering Principles

Project Atlas follows:

- Domain-Driven Design (DDD)
- SOLID Principles
- RESTful APIs
- OpenAPI 3.1
- RFC 9457 Problem Details
- UUID Primary Keys
- Conventional Commits
- AI-Agent-Native Development

---

# Repository Structure

```
project-atlas/
├── apps/
│   ├── api/
│   ├── web/
│   └── ai/
├── docs/
├── specs/
├── .agents/
├── .devcontainer/
└── docker-compose.yml
```

---

# Development Roadmap

## Phase 1 — Foundation ✅

- Monorepo
- Dev Container
- Rails 8
- PostgreSQL
- Redis
- Architecture
- Engineering Standards

## Phase 2 — Identity

- Authentication
- Organizations
- Memberships
- JWT
- Authorization

## Phase 3 — Ticket Management

- CSV Import
- Ticket Processing
- Background Jobs

## Phase 4 — AI Intelligence

- Ticket Classification
- Sentiment Analysis
- Executive Summaries
- Recommendations

## Phase 5 — Reporting

- Dashboards
- Reports
- Analytics

## Phase 6 — Production

- Docker
- Kubernetes
- Terraform
- CI/CD
- Monitoring

---

# Documentation

The repository includes:

- Project Charter
- Product Requirements
- Domain Model
- System Architecture
- API Design
- Database Design
- Engineering Principles
- Architecture Decision Records (ADRs)
- AI Agent Guides

---

# AI-First Development

Project Atlas is designed to work effectively with AI coding agents.

The repository includes dedicated AI documentation covering:

- Project context
- Coding standards
- Feature workflow
- Architecture index
- Engineering playbook

---

# Current Status

🚧 Active Development

Sprint 1: Identity & Authentication