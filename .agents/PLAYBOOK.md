# Project Atlas Playbook

## Purpose

This playbook provides repeatable implementation patterns for Project Atlas.

It is intended for both human developers and AI coding agents.

Every recipe follows the engineering principles defined in the project.

---

# General Feature Workflow

Every feature should follow this sequence.

1. Understand the business problem.
2. Review relevant documentation.
3. Review existing ADRs.
4. Design the API.
5. Design database changes.
6. Implement.
7. Write tests.
8. Update documentation.
9. Commit using Conventional Commits.

Never skip documentation.

---

# Recipe: Add a New Domain

Examples:

- Identity
- Tickets
- Reports
- Billing

Checklist

- Create domain documentation.
- Define business rules.
- Define entities.
- Define relationships.
- Design APIs.
- Design database schema.
- Record ADR if architecture changes.

Only then begin implementation.

---

# Recipe: Add a New Model

Checklist

- Confirm it belongs to an existing domain.
- Design relationships.
- Use UUID primary keys.
- Add indexes.
- Add foreign keys.
- Add validations.
- Add model tests.

Avoid unnecessary callbacks.

---

# Recipe: Add a New API Endpoint

Checklist

- Update API documentation.
- Define request.
- Define response.
- Define error responses.
- Implement controller.
- Implement service.
- Add request tests.
- Update OpenAPI specification.

Controllers should never contain business logic.

---

# Recipe: Add a Service

Services represent business workflows.

Examples

- Login
- Invite User
- Import Tickets
- Generate Report

Checklist

- One responsibility.
- Small class.
- Reusable.
- Tested.
- No presentation logic.

---

# Recipe: Add a Background Job

Use Sidekiq for long-running operations.

Examples

- CSV Import
- AI Analysis
- Report Generation

Checklist

- Idempotent.
- Retry-safe.
- Log failures.
- Avoid database transactions spanning external calls.

---

# Recipe: Add an AI Feature

Checklist

- Define business objective.
- Define prompt.
- Define input.
- Define output.
- Handle failures.
- Log requests.
- Store responses if required.

Never embed prompts directly inside controllers.

---

# Recipe: Add a Database Migration

Checklist

- Review existing schema.
- Use UUID references.
- Add indexes.
- Add foreign keys.
- Make migrations reversible.
- Consider production impact.

Avoid destructive changes without a migration strategy.

---

# Recipe: Add Authorization

Checklist

- Identify protected resource.
- Define roles.
- Update policy.
- Add authorization tests.
- Update documentation.

Authorization should be organization-scoped.

---

# Recipe: Add Documentation

Update the appropriate documents.

Examples

- Domain documentation
- API documentation
- ADRs
- Development roadmap

Documentation should evolve with the implementation.

---

# Recipe: Review Before Commit

Before every commit

✓ Tests pass

✓ Documentation updated

✓ No duplicate logic

✓ Follows engineering principles

✓ Commit message follows Conventional Commits

---

# Common Mistakes

Avoid

- Fat controllers
- Fat models
- Duplicate business logic
- Hidden side effects
- Premature optimization
- Skipping documentation
- Large commits
- Introducing new patterns without discussion

---

# Decision Checklist

Before implementing anything, ask:

- Does this belong to the correct domain?
- Is there already an existing implementation?
- Is the solution simple?
- Does it follow the engineering principles?
- Does it require an ADR?
- Does it require documentation updates?
- Can another engineer understand this in six months?

If any answer is "No", stop and redesign before coding.

---

# Definition of Done

A feature is complete only when:

- Business requirements are implemented.
- Tests pass.
- Documentation is updated.
- API documentation is updated.
- OpenAPI specification is updated.
- Code review checklist passes.
- Commit history is clean.