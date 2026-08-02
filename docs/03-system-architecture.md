# System Architecture

## Overview

Project Atlas is built as a modular AI-native SaaS platform.

The system is composed of three applications inside a single monorepo.


                   User
                     │
                     ▼
              Vue 3 Frontend
                     │
          HTTPS REST API
                     │
                     ▼
              Rails API
                     │
      ┌──────────────┼──────────────┐
      │              │              │
      ▼              ▼              ▼
 PostgreSQL       Redis         Sidekiq
      │                              │
      │                              ▼
      │                     AI Processing Jobs
      │                              │
      └──────────────┬───────────────┘
                     ▼
              FastAPI AI Service
                     │
         OpenAI / Anthropic


---

# Components

## Vue Application

Responsibilities

- Authentication
- Dashboard
- Ticket Upload
- Reports
- Organization Settings

No business logic.

---

## Rails API

Responsibilities

- Authentication
- Authorization
- Organization Management
- Ticket Management
- Background Jobs
- REST APIs

Acts as the central application.

---

## PostgreSQL

Stores

- Organizations
- Users
- Tickets
- Reports
- AI Results

---

## Redis

Used for

- Background jobs
- Caching
- Rate limiting

---

## Sidekiq

Responsible for

- CSV Processing
- AI Analysis
- Report Generation

---

## FastAPI

Responsible for

- Ticket Classification
- Sentiment Analysis
- Feature Extraction
- Executive Summaries
- Knowledge Suggestions

No database access.

Only AI.

---

# Request Flow

User uploads CSV

↓

Rails validates upload

↓

Upload stored

↓

Sidekiq job created

↓

FastAPI analyses tickets

↓

Results returned

↓

Rails stores results

↓

Dashboard updated

---

# Security

- JWT Authentication
- Role Based Access
- Organization Isolation
- HTTPS
- Input Validation

---

# Scalability

Each application can scale independently.

- Multiple Rails containers
- Multiple Sidekiq workers
- Multiple AI workers

without changing application architecture.