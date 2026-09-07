# Identity API

## Overview

The Identity API manages authentication, organizations, memberships, and user sessions.

Base URL

```
/api/v1
```

---

# Authentication

JWT Bearer Token

```
Authorization: Bearer <access_token>
```

---

# Endpoints

## Login

POST /api/v1/auth/login

Request

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

Response

```json
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 3600
  }
}
```

---

## Refresh Token

POST /api/v1/auth/refresh

Request

```json
{
  "refresh_token": "..."
}
```

Response

```json
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 3600
  }
}
```

---

## Logout

POST /api/v1/auth/logout

Request

No body

Response

HTTP 204 No Content

---

## Current User

GET /api/v1/me

Response

```json
{
  "data": {
    "id": "...",
    "email": "...",
    "first_name": "...",
    "last_name": "...",
    "organizations": []
  }
}
```

---

## Organizations

GET /api/v1/organizations

Returns organizations the current user belongs to.

---

## Switch Organization

POST /api/v1/organizations/:id/switch

Changes the active organization context.

---

# Error Responses

Errors follow RFC 9457 Problem Details.

Example

```json
{
  "type": "/errors/unauthorized",
  "title": "Unauthorized",
  "status": 401,
  "detail": "Invalid credentials"
}
```