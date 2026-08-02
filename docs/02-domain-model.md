# Domain Model

## Overview

Project Atlas revolves around organizations analyzing customer support conversations to generate AI-powered business insights.

---

# Core Entities

## Organization

Represents a customer workspace.

### Responsibilities

- Owns all business data.
- Manages users.
- Owns uploads.
- Owns reports.

Relationships


Organization

├── Users

├── Uploads

├── Reports

└── Knowledge Suggestions


---

## User

Represents an authenticated user.

Responsibilities

- Login
- Upload tickets
- View dashboards
- Generate reports

Relationships


User

belongs_to Organization


---

## Upload

Represents a CSV upload.

Responsibilities

- Store metadata
- Track processing
- Track failures

Attributes

- filename
- status
- uploaded_at

Relationships


Upload

belongs_to Organization

has_many Tickets


---

## Ticket

Represents a single customer support conversation.

Attributes

- subject
- description
- priority
- status
- customer
- agent
- created_at

Relationships


Ticket

belongs_to Upload

has_one AIAnalysis


---

## AI Analysis

Represents AI-generated analysis.

Responsibilities

- Categorization
- Sentiment
- Summary
- Root Cause
- Feature Requests

Relationships


AIAnalysis

belongs_to Ticket


---

## Report

Represents an exported report.

Responsibilities

- Executive Summary
- Weekly Report
- Monthly Report

Relationships


Report

belongs_to Organization


---

## Knowledge Suggestion

Represents documentation suggested by AI.

Examples

- Missing FAQ
- Missing Troubleshooting Guide
- Missing Onboarding Article

Relationships


KnowledgeSuggestion

belongs_to Organization


---

# Aggregate Root

Organization

All business operations originate from the Organization.

This provides natural tenant isolation.

---

# Future Entities

- AI Agent
- Integration
- Notification
- Billing
- Subscription
- Audit Log
- API Key