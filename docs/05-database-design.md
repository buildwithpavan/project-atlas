# Database Design

## Overview

Project Atlas uses PostgreSQL with row-level multi-tenancy.

Every business table contains an organization_id column to ensure tenant isolation.

---

# Entity Relationship Diagram


Organization
    │
    ├──────────────┐
    │              │
Users         Uploads
                    │
                    │
                Tickets
                    │
            ┌───────┴────────┐
            │                │
      AIAnalysis      KnowledgeSuggestion

Organization
        │
        └──── Reports


---

# organizations

| Column | Type |
|----------|------|
| id | uuid |
| name | string |
| slug | string |
| created_at | timestamp |
| updated_at | timestamp |

---

# users

| Column | Type |
|----------|------|
| id | uuid |
| organization_id | uuid |
| first_name | string |
| last_name | string |
| email | string |
| password_digest | string |
| role | enum |
| created_at | timestamp |

Indexes

- email (unique)

---

# uploads

| Column | Type |
|----------|------|
| id | uuid |
| organization_id | uuid |
| filename | string |
| status | enum |
| total_records | integer |
| processed_records | integer |
| failed_records | integer |
| uploaded_by | uuid |
| created_at | timestamp |

---

# tickets

| Column | Type |
|----------|------|
| id | uuid |
| organization_id | uuid |
| upload_id | uuid |
| customer_name | string |
| customer_email | string |
| subject | string |
| description | text |
| priority | enum |
| status | enum |
| category | string |
| created_at | timestamp |

Indexes

- organization_id
- upload_id
- status
- priority

---

# ai_analyses

| Column | Type |
|----------|------|
| id | uuid |
| organization_id | uuid |
| ticket_id | uuid |
| sentiment | enum |
| summary | text |
| category | string |
| confidence | decimal |
| feature_request | boolean |
| bug_report | boolean |
| knowledge_gap | boolean |
| processed_at | timestamp |

---

# reports

| Column | Type |
|----------|------|
| id | uuid |
| organization_id | uuid |
| report_type | enum |
| title | string |
| summary | text |
| generated_at | timestamp |

---

# knowledge_suggestions

| Column | Type |
|----------|------|
| id | uuid |
| organization_id | uuid |
| title | string |
| description | text |
| confidence | decimal |
| created_at | timestamp |

---

# Relationships

Organization

- has_many Users
- has_many Uploads
- has_many Tickets
- has_many Reports
- has_many KnowledgeSuggestions

Upload

- has_many Tickets

Ticket

- has_one AIAnalysis

---

# Multi-Tenancy

Every query must be scoped using:

organization_id

No cross-tenant queries are permitted.

---

# Future Tables

- integrations
- notifications
- api_keys
- audit_logs
- subscriptions
- feature_flags