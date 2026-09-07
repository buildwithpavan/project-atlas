# Feature Implementation Workflow

## Purpose

Every feature implemented in Project Atlas must follow this workflow.

This process applies to both human developers and AI coding agents.

---

# Step 1 — Understand the Business Problem

Before writing code:

- Identify the business capability.
- Determine the affected domain.
- Review existing documentation.

Never implement a feature without understanding its purpose.

---

# Step 2 — Review Existing Architecture

Review:

- Engineering Principles
- Domain documentation
- ADRs
- Existing services
- Existing models

Prefer extending existing components.

Avoid duplication.

---

# Step 3 — Design

Before implementation:

- API Contract
- Database changes
- Service boundaries
- Authorization
- Error handling

Design first.

Code second.

---

# Step 4 — Implement

Implementation order:

1. Database
2. Models
3. Services
4. Policies
5. Controllers
6. Serializers
7. Background Jobs

Keep commits small.

---

# Step 5 — Test

Every feature should include:

- Unit tests
- Request tests
- Integration tests (when applicable)

Critical business logic must always be tested.

---

# Step 6 — Documentation

Update:

- Domain document
- API document
- ADR (if architecture changed)

Documentation is part of the feature.

---

# Step 7 — Review

Before merging:

- RuboCop passes
- Brakeman passes
- Tests pass
- Documentation updated
- Commit message follows Conventional Commits

---

# Principles

Always prefer:

- Simplicity
- Readability
- Small classes
- Explicit interfaces

Avoid:

- Large controllers
- Fat models
- Duplicate logic
- Premature optimization

Every implementation should improve the overall quality of the codebase.