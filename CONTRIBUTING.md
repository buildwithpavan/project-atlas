# Contributing to Project Atlas

Thank you for contributing to Project Atlas.

Project Atlas is a production-grade reference implementation of an AI-native SaaS platform.

This document explains the development workflow.

---

# Before You Start

Read the following documents first:

1. README.md
2. docs/13-engineering-principles.md
3. .agents/PROJECT_CONTEXT.md
4. .agents/FEATURE_WORKFLOW.md

---

# Development Workflow

Every feature follows this order:

1. Understand the business problem.
2. Review architecture documentation.
3. Design the API.
4. Design database changes.
5. Implement.
6. Add tests.
7. Update documentation.
8. Commit.

---

# Branch Naming

Examples:

feature/identity

feature/ticket-import

feature/report-generation

fix/authentication

refactor/services

docs/api

---

# Commit Messages

Use Conventional Commits.

Examples:

feat(identity): implement login endpoint

feat(tickets): add CSV importer

fix(api): handle validation errors

docs(identity): update authentication flow

refactor(ai): simplify prompt builder

---

# Pull Requests

Every pull request should include:

- Purpose
- Summary of changes
- Testing performed
- Documentation updates

---

# Code Review Checklist

Before requesting review:

- Tests pass
- RuboCop passes
- Brakeman passes
- Documentation updated
- No unnecessary complexity

---

# Coding Standards

- Keep controllers thin.
- Keep services focused.
- Avoid duplicate logic.
- Follow Rails conventions.
- Prefer composition over inheritance.

---

# Documentation

Documentation is considered part of the implementation.

Every significant feature should update:

- Domain documentation
- API documentation
- ADRs (if architecture changes)

---

# AI Contributions

AI-assisted development is encouraged.

However, all generated code should be:

- Reviewed
- Tested
- Documented

AI-generated code should follow the same engineering standards as human-written code.