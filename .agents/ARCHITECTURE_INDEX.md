# Architecture Index

## Purpose

This document is the entry point for understanding Project Atlas.

AI coding agents and developers should use this document to quickly locate project documentation before making changes.

---

# Project Documentation

## Project Overview

- docs/00-project-charter.md

Defines the project vision, objectives, stakeholders, and overall scope.

---

## Product Requirements

- docs/01-product-requirements.md

Describes functional and non-functional requirements.

---

## Domain Model

- docs/02-domain-model.md

Defines the core business entities and their relationships.

---

## System Architecture

- docs/03-system-architecture.md

Explains the overall technical architecture, system components, development environment, and deployment architecture.

---

## API Design

- docs/04-api-design.md

Defines API conventions and design standards.

---

## Database Design

- docs/05-database-design.md

Documents database architecture, relationships, constraints, and indexing strategy.

---

## AI Design

- docs/06-ai-design.md

Describes the AI service architecture and integrations.

---

## Security

- docs/07-security.md

Security principles, authentication, authorization, and best practices.

---

## Deployment

- docs/08-deployment.md

Deployment strategy for development and production environments.

---

## Decision Log

- docs/09-decision-log.md

Historical architectural and engineering decisions.

---

## Development Roadmap

- docs/10-development-roadmap.md

Current implementation roadmap and project milestones.

---

## Identity Domain

- docs/11-identity-domain.md

Business rules and architecture for authentication, organizations, users, and memberships.

---

## Identity API

- docs/12-identity-api.md

REST API contract for the Identity domain.

---

## Engineering Principles

- docs/13-engineering-principles.md

Core engineering standards that every implementation must follow.

---

# Architecture Decision Records (ADRs)

Location:

```
docs/adr/
```

Read all relevant ADRs before introducing architectural changes.

---

# AI Documentation

## Project Context

- .agents/PROJECT_CONTEXT.md

High-level overview of the project.

---

## AI Agent Guide

- .agents/AGENTS.md

Instructions for AI coding agents.

---

## Feature Workflow

- .agents/FEATURE_WORKFLOW.md

Defines the standard implementation workflow for every feature.

---

# Repository Structure

```
project-atlas/
│
├── .agents/
├── .devcontainer/
├── .github/
├── apps/
│   ├── api/
│   ├── web/
│   └── ai/
├── docs/
│   └── adr/
├── specs/
├── docker-compose.yml
├── CONTRIBUTING.md
└── README.md
```

---

# Reading Order

For new contributors and AI agents, the recommended reading order is:

1. README.md
2. .agents/PROJECT_CONTEXT.md
3. .agents/AGENTS.md
4. docs/13-engineering-principles.md
5. docs/03-system-architecture.md
6. Relevant domain documentation
7. Relevant API documentation
8. Relevant ADRs

---

# Before Implementing Any Feature

Always verify:

- The business domain is clearly identified.
- Existing documentation has been reviewed.
- Existing architecture is respected.
- Similar implementations do not already exist.
- Documentation will be updated alongside the implementation.

---

# Guiding Principle

Project Atlas prioritizes:

- Maintainability
- Simplicity
- Consistency
- Explicit architecture
- AI-assisted development
- Production-ready engineering

When in doubt, prefer existing project conventions over introducing new patterns.