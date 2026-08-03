System Architecture

Overview

Project Atlas is built as a modular, AI-native SaaS platform following a monorepo architecture. The system consists of independent applications that can be developed, deployed, and scaled independently while sharing a common codebase and development workflow.

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

Technology Stack

Layer| Technology| Version
Backend Framework| Ruby on Rails| 8.1
Programming Language| Ruby| 3.4
Frontend| Vue 3| Planned
AI Service| FastAPI| Planned
AI Language| Python| 3.12
JavaScript Runtime| Node.js| 22
Database| PostgreSQL| 17
Cache| Redis| 7
Background Jobs| Sidekiq| Latest
Container Platform| Docker Compose| Latest
Development Environment| VS Code Dev Containers| Latest
Version Control| Git + GitHub| Latest

---

Components

Vue Application

Responsibilities

- Authentication
- Dashboard
- Ticket Upload
- Reports
- Organization Settings

No business logic resides in the frontend.

---

Rails API

Responsibilities

- Authentication
- Authorization
- Organization Management
- Ticket Management
- Background Jobs
- REST APIs

Acts as the central application responsible for orchestrating business workflows.

---

PostgreSQL

Stores

- Organizations
- Users
- Tickets
- Reports
- AI Results

---

Redis

Used for

- Background jobs
- Caching
- Rate limiting

---

Sidekiq

Responsible for

- CSV Processing
- AI Analysis
- Report Generation

---

FastAPI

Responsible for

- Ticket Classification
- Sentiment Analysis
- Feature Extraction
- Executive Summaries
- Knowledge Suggestions

The AI service has no direct database access and communicates only through the Rails API.

---

Request Flow

User uploads CSV
        │
        ▼
Rails validates upload
        │
        ▼
Upload stored
        │
        ▼
Sidekiq job created
        │
        ▼
FastAPI analyses tickets
        │
        ▼
Results returned
        │
        ▼
Rails stores results
        │
        ▼
Dashboard updated

---

Security

- JWT Authentication
- Role Based Access Control (RBAC)
- Organization Isolation (Multi-tenancy)
- HTTPS
- Input Validation

---

Scalability

Each application can scale independently without changing the overall architecture.

- Multiple Rails API containers
- Multiple Sidekiq workers
- Multiple AI workers
- Dedicated PostgreSQL instance
- Dedicated Redis instance

---

Development Environment Architecture

Overview

Project Atlas uses a containerized development environment powered by VS Code Dev Containers and Docker Compose. This provides a reproducible development setup while keeping the host machine free from project-specific runtime dependencies.

Development Architecture

                          Developer
                              │
                              ▼
                     VS Code + WSL2
                              │
                              ▼
                 Docker Compose Environment
                              │
      ┌───────────────────────┼────────────────────────┐
      │                       │                        │
      ▼                       ▼                        ▼
┌──────────────┐      ┌────────────────┐      ┌────────────────┐
│ Dev Container│      │ PostgreSQL 17 │      │    Redis 7     │
│    (app)     │      │                │      │                │
│──────────────│      │ Development DB │      │ Cache          │
│ Ruby 3.4     │      │ Test DB        │      │ Background Jobs│
│ Rails 8.1    │      └────────────────┘      └────────────────┘
│ Node.js 22   │
│ Python 3.12  │
│ Bundler      │
└──────────────┘

---

Repository Structure

project-atlas/
├── .devcontainer/
│   ├── Dockerfile
│   └── devcontainer.json
├── apps/
│   ├── api/        # Rails API
│   ├── web/        # Vue Frontend
│   └── ai/         # FastAPI AI Service
├── docs/
├── specs/
├── docker-compose.yml
├── mise.toml
└── README.md

---

Current Development Status

Completed

- VS Code Dev Container configured
- Docker Compose development environment configured
- Ruby 3.4 runtime installed
- Rails 8.1 API application bootstrapped
- PostgreSQL 17 configured
- Redis 7 configured
- Bundler configured
- Development and test databases created
- Rails health endpoint ("/up") verified

---

Development Workflow

1. Clone the repository.
2. Open the repository in VS Code.
3. Reopen the project in the Dev Container.
4. Start supporting services:

docker compose up -d

5. Start the Rails application:

cd apps/api
bin/rails server

6. Verify the application:

http://localhost:3000/up

---

Design Principles

- Container-first development
- Consistent runtime versions across all development environments
- Host machine remains free from project-specific dependencies
- Docker Compose manages local infrastructure services
- Reproducible onboarding experience for all contributors
- Infrastructure as Code
- Modular monorepo architecture