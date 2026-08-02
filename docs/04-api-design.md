# API Design

## Authentication

### POST /api/v1/auth/register

Registers a new user and organization.

Request

json
{
  "organization_name": "Acme Inc",
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password"
}


Response

json
{
  "token": "...",
  "user": {},
  "organization": {}
}


---

### POST /api/v1/auth/login

Returns JWT token.

---

### POST /api/v1/auth/logout

Invalidates token.

---

# Organizations

### GET /api/v1/organization

Returns current organization.

---

# Uploads

### POST /api/v1/uploads

Upload CSV.

Returns upload_id.

---

### GET /api/v1/uploads

List uploads.

---

### GET /api/v1/uploads/:id

Upload status.

---

# Tickets

### GET /api/v1/tickets

List tickets.

Supports

- search
- pagination
- filters

---

### GET /api/v1/tickets/:id

Ticket details.

---

# Dashboard

### GET /api/v1/dashboard

Returns

- total tickets
- sentiment
- recurring issues
- feature requests
- executive summary

---

# Reports

### GET /api/v1/reports

List reports.

---

### POST /api/v1/reports

Generate report.

---

### GET /api/v1/reports/:id

Download report.

---

# Health

### GET /health

Application health.

---

# Versioning

All APIs are versioned.


/api/v1/


Future


/api/v2/