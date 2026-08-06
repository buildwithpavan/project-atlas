# Coding Standards

## Purpose

This document defines the coding standards for Project Atlas.

Every contribution, whether written by a human or an AI coding agent, should follow these standards.

---

# General Principles

Always write code that is:

- Simple
- Readable
- Maintainable
- Explicit
- Testable

Code is written for humans first.

---

# Ruby

Prefer expressive Ruby.

Use early returns.

Avoid deeply nested conditionals.

Prefer keyword arguments.

Use immutable constants where appropriate.

Freeze string literals.

---

# Rails

Follow Rails conventions unless there is a documented architectural reason not to.

Prefer built-in Rails features before introducing external gems.

Keep configuration minimal.

---

# Controllers

Controllers should:

- Authenticate requests.
- Authorize requests.
- Validate parameters.
- Call application services.
- Return responses.

Controllers should never contain business logic.

---

# Models

Models represent the business domain.

Models may contain:

- Associations
- Validations
- Small domain behaviors

Avoid:

- Service orchestration
- External API calls
- Complex workflows

---

# Services

Services implement business workflows.

Each service should have one responsibility.

Example:

Identity::Login

Organizations::InviteMember

Tickets::ImportCsv

Reports::Generate

---

# Queries

Queries encapsulate complex database access.

Avoid placing large ActiveRecord queries inside controllers or services.

---

# Background Jobs

Background jobs should:

- Be idempotent.
- Be retry-safe.
- Delegate business logic to services.

Jobs coordinate work.

Services perform work.

---

# Naming

Use clear names.

Good:

GenerateExecutiveReport

ImportTickets

InviteMember

Poor:

Processor

Manager

Handler

Util

Helper

---

# Methods

Methods should be:

- Small
- Focused
- Easy to understand

Prefer extracting methods over deeply nested logic.

---

# Error Handling

Raise domain-specific errors.

Avoid rescuing StandardError unless absolutely necessary.

Use ApplicationError for application-level exceptions.

---

# Logging

Log meaningful business events.

Never log:

- Passwords
- Tokens
- Secrets
- Sensitive customer data

---

# Database

Always:

- Add indexes where appropriate.
- Add foreign keys.
- Use transactions for multi-step operations.
- Avoid N+1 queries.

---

# Security

Never trust user input.

Always:

- Validate input.
- Authorize access.
- Escape output where required.

---

# Testing

Every feature should include tests.

Test business behavior rather than implementation details.

---

# Documentation

Documentation is part of the implementation.

When adding a significant feature, update the appropriate documentation.

---

# AI Guidelines

AI-generated code should:

- Follow existing project conventions.
- Avoid introducing unnecessary abstractions.
- Reuse existing implementations.
- Keep commits focused.
- Update documentation when required.

---

# Final Principle

When faced with multiple valid solutions, choose the one that is easiest for another engineer to understand six months from now.