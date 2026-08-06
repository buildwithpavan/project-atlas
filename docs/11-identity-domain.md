# Identity Domain

## Overview

The Identity domain is responsible for authentication, authorization, users, organizations, memberships, and access control.

It is the foundation of Project Atlas.

Every authenticated request passes through this domain.

---

# Goals

- Support multi-tenant SaaS architecture.
- Support users belonging to multiple organizations.
- Support role-based access control (RBAC).
- Secure authentication using JWT.
- Refresh token support.
- Invitation-based organization onboarding.

---

# Domain Model

```
Organization
      │
      │ 1
      │
      ▼
Membership
      ▲
      │
      │ *
      │
      User
```

---

# Entities

## User

Represents a person using Atlas.

Responsibilities

- Authentication
- Profile
- Organization membership

---

## Organization

Represents a customer/company.

Responsibilities

- Own data
- Manage members
- Own reports
- Own tickets

---

## Membership

Represents a user's relationship with an organization.

Responsibilities

- Role
- Permissions
- Invitation status

---

# Relationships

Organization

- has_many memberships
- has_many users through memberships

User

- has_many memberships
- has_many organizations through memberships

Membership

- belongs_to user
- belongs_to organization

---

# Roles

Owner

- Full access
- Billing
- Delete organization
- Manage members

Admin

- Manage users
- Manage tickets
- Manage reports

Member

- Upload tickets
- View reports

Viewer

- Read-only access

---

# Authentication

Authentication uses JWT.

Flow

User Login

↓

Validate credentials

↓

Issue Access Token

↓

Issue Refresh Token

↓

Authenticated Requests

↓

Token Validation

---

# Authorization

Authorization is organization scoped.

Every request belongs to exactly one organization.

Permissions are determined by Membership.role.

---

# Future Features

- Single Sign-On (SSO)
- Google Login
- Microsoft Entra ID
- MFA
- API Keys
- Service Accounts

---

# Design Principles

- Organization is the tenant boundary.
- Users may belong to multiple organizations.
- No business data belongs directly to users.
- Authorization is membership-based.
- JWT authentication.
- UUID primary keys.