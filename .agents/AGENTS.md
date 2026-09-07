# AI Agent Guide

## Purpose

Project Atlas is designed to be AI-agent friendly from the beginning.

This document explains how AI coding agents should contribute to the project.

Examples include:

- ChatGPT
- GitHub Copilot
- Claude Code
- Gemini
- Future AI development tools

---

# Project Goals

Atlas is an AI-native SaaS platform built with:

- Ruby on Rails
- Vue 3
- FastAPI
- PostgreSQL
- Redis
- Docker
- Kubernetes
- Terraform

The project demonstrates production-grade backend engineering.

---

# Engineering Workflow

Every feature follows this workflow.

1. Understand the business domain.
2. Review the relevant domain document.
3. Review existing ADRs.
4. Design the API.
5. Design database changes.
6. Implement.
7. Add tests.
8. Update documentation.
9. Commit using conventional commits.

---

# Project Structure

The repository is organized into:

- apps/
- docs/
- specs/
- infrastructure/
- .ai/

Do not introduce new top-level directories without discussion.

---

# Architecture Principles

Always follow:

- Domain-Driven Design
- SOLID
- REST
- OpenAPI
- RFC 9457
- UUID primary keys

Avoid unnecessary abstractions.

---

# Coding Principles

Controllers

- Thin
- No business logic

Models

- Represent the domain
- Small behaviors only

Services

- Implement business workflows
- One responsibility per service

Queries

- Encapsulate complex database queries

Policies

- Authorization only

---

# Before Writing Code

Always check:

- Existing documentation
- Existing ADRs
- Existing services
- Existing models

Prefer extending existing implementations over creating duplicates.

---

# API Rules

Every endpoint must:

- Use REST principles.
- Use versioned routes.
- Return consistent JSON responses.
- Use appropriate HTTP status codes.

---

# Database Rules

Always:

- Use UUIDs.
- Add indexes where appropriate.
- Add foreign keys.
- Avoid N+1 queries.
- Use transactions for multi-step operations.

---

# Documentation Rules

Every significant feature should update:

- Domain document
- API contract
- ADR (if needed)

Documentation is part of the implementation.

---

# Commit Rules

Use Conventional Commits.

Examples:

feat(identity): implement login

fix(api): handle validation errors

docs(identity): update authentication flow

refactor(tickets): simplify CSV importer

---

# AI Agent Behaviour

Prefer:

- Simple code
- Readable code
- Small classes
- Explicit interfaces

Avoid:

- Large controllers
- Hidden side effects
- Premature optimization
- Unnecessary dependencies

When uncertain, prefer consistency with the existing architecture.