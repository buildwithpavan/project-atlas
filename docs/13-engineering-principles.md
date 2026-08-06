# Engineering Principles

## Purpose

This document defines the engineering principles for Project Atlas.

Every implementation, design decision, and architectural change must align with these principles.

These principles apply equally to human developers and AI coding agents.

---

# 1. Domain-Driven Design (DDD)

Project Atlas is organized around business domains rather than technical layers.

Business domains include:

- Identity
- Organizations
- Tickets
- Reports
- AI
- Billing

Every feature should belong to exactly one primary domain.

---

# 2. Convention Over Configuration

Prefer Rails conventions unless there is a strong architectural reason not to.

Avoid unnecessary abstractions.

Follow established Rails patterns whenever possible.

---

# 3. SOLID Principles

All application code should follow SOLID principles.

- Single Responsibility Principle
- Open/Closed Principle
- Liskov Substitution Principle
- Interface Segregation Principle
- Dependency Inversion Principle

---

# 4. Thin Controllers

Controllers should only be responsible for:

- Receiving requests
- Validating input
- Calling application services
- Returning responses

Business logic does not belong in controllers.

---

# 5. Business Logic Lives in Services

Business workflows belong in service objects.

Examples:

- Login
- Invite User
- Import Tickets
- Generate Reports

Services should remain small, focused, and reusable.

---

# 6. Models Represent the Domain

Active Record models should represent the business domain.

Models may contain:

- Associations
- Validations
- Small domain behaviors

Complex workflows should be implemented in services.

---

# 7. API First

Every API endpoint should be designed before implementation.

The order is:

1. Domain Design
2. API Contract
3. Database Design
4. Implementation
5. Tests
6. Documentation

---

# 8. REST Standards

Project Atlas follows REST principles.

- Resource-oriented URLs
- Standard HTTP methods
- Appropriate HTTP status codes
- Versioned APIs

Base path:

```
/api/v1
```

---

# 9. OpenAPI

Every public API must be documented using OpenAPI 3.1.

Documentation is maintained alongside implementation.

---

# 10. Error Handling

Errors follow RFC 9457 (Problem Details for HTTP APIs).

Every error should provide:

- type
- title
- status
- detail

Application errors should inherit from ApplicationError.

---

# 11. Database Design

Database principles:

- UUID primary keys
- Foreign key constraints
- Proper indexing
- Transactions where required
- Avoid N+1 queries

---

# 12. Multi-Tenancy

Organization is the tenant boundary.

Business data belongs to organizations, not users.

Users may belong to multiple organizations.

Authorization is membership-based.

---

# 13. Security

Security is built into the application.

Principles include:

- JWT authentication
- Role-based access control (RBAC)
- Secure password hashing
- Strong parameter validation
- OWASP Top 10 awareness
- Principle of least privilege

---

# 14. Performance

Performance considerations include:

- Database query optimization
- Background processing
- Caching
- Pagination
- Efficient API responses

Performance should be measured before optimization.

---

# 15. Testing

Every feature should include automated tests.

Testing pyramid:

- Unit Tests
- Request/API Tests
- Integration Tests

Critical business logic must be tested.

---

# 16. Observability

Applications should be observable.

This includes:

- Structured logging
- Error tracking
- Metrics
- Health checks

Production issues should be diagnosable.

---

# 17. AI-First Engineering

Project Atlas is designed to work effectively with AI coding agents.

Engineering decisions should:

- Keep modules small
- Minimize hidden coupling
- Prefer explicit interfaces
- Maintain high-quality documentation
- Keep architectural decisions recorded

---

# 18. Documentation

Documentation is part of the implementation.

Every major feature should include:

- Domain Design
- API Contract
- ADR (if applicable)

Documentation should evolve with the code.

---

# 19. Infrastructure

Infrastructure is treated as code.

Project Atlas will use:

- Docker
- Kubernetes
- Terraform
- GitHub Actions

Development and production environments should remain as consistent as possible.

---

# 20. Continuous Improvement

Engineering practices evolve over time.

Architectural decisions should be reviewed when new information becomes available.

Refactoring is encouraged when it improves maintainability without introducing unnecessary complexity.

---

# Engineering Philosophy

Project Atlas prioritizes:

- Simplicity over cleverness
- Readability over brevity
- Explicitness over magic
- Composition over inheritance
- Standards over custom conventions
- Automation over manual processes
- Long-term maintainability over short-term convenience

Every change should leave the codebase easier to understand than before.