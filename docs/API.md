# Chronicle REST API Reference

**Version:** 1.0.0
**Base URL:** `http://localhost:8765`

The Chronicle API is a local REST server that runs on your Mac, allowing companion apps and integrations to access your bill data.

## Authentication

All endpoints (except `/health` and `/openapi.json`) require API key authentication.

### Methods

**Bearer Token:**
```
Authorization: Bearer YOUR_API_KEY
```

**API Key Header:**
```
X-API-Key: YOUR_API_KEY
```

### Managing Your API Key

Generate and manage your API key in **Chronicle → Settings → API**.

---

## Endpoints

### Bills

#### List All Bills
```
GET /bills
```

**Response:**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Netflix",
    "amountCents": 1599,
    "currency": "USD",
    "dueDay": 15,
    "dueDate": "2024-02-15T00:00:00Z",
    "recurrence": "Monthly",
    "category": "Subscriptions",
    "isPaid": false,
    "isActive": true,
    ...
  }
]
```

#### Get Bill
```
GET /bills/{id}
```

**Response:** Single bill object (see above)

#### Create Bill
```
POST /bills
```

**Request Body:**
```json
{
  "name": "Netflix",
  "amountCents": 1599,
  "currency": "USD",
  "dueDay": 15,
  "dueDate": "2024-02-15T00:00:00Z",
  "recurrence": "Monthly",
  "category": "Subscriptions"
}
```

#### Update Bill
```
PUT /bills/{id}
```

**Request Body:** Partial bill object with fields to update

#### Delete Bill
```
DELETE /bills/{id}
```

**Response:** `{"message": "Bill deleted"}`

---

### Summary

#### Get Summary
```
GET /summary
```

**Response:**
```json
{
  "monthly": {
    "total": 1250.00,
    "paid": 450.00,
    "unpaid": 800.00,
    "count": 12
  },
  "yearly": {
    "total": 15000.00,
    "paid": 5400.00,
    "unpaid": 9600.00,
    "count": 144
  },
  "byCategory": {
    "housing": 1200.00,
    "utilities": 200.00,
    "subscriptions": 150.00
  }
}
```

---

### Household

#### Get Household
```
GET /household
```

**Response:**
```json
{
  "household": {
    "id": "...",
    "name": "My Home",
    "currency": "USD",
    "createdAt": "2024-01-01T00:00:00Z"
  },
  "balances": [
    {
      "memberId": "...",
      "memberName": "John",
      "balance": 250.00
    }
  ]
}
```

---

### Webhooks

#### Zapier Trigger Webhook
```
POST /webhooks/zapier
```

Receives trigger events from Zapier/Make automation platform.

**Request Body:**
```json
{
  "triggerType": "bill_due",
  "eventId": "evt_123",
  "timestamp": "2024-01-15T10:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Webhook received"
}
```

#### Create Bill via Webhook
```
POST /webhooks/bill/create
```

Create a bill from Zapier/Make automation.

**Request Body:**
```json
{
  "name": "Electricity Bill",
  "amount": 150.00,
  "due_date": "2024-02-01",
  "category": "Utilities",
  "currency": "USD"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Bill created",
  "billId": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

### IFTTT

#### Get Upcoming Bills (IFTTT)
```
GET /ifttt/bills/due
```

Returns upcoming bills in IFTTT-friendly JSON format.

**Response:**
```json
{
  "count": 3,
  "bills": [
    {
      "name": "Netflix",
      "amount": "$15.99",
      "dueDate": "2024-02-01T00:00:00Z",
      "category": "Subscriptions"
    }
  ]
}
```

#### Create Bill (IFTTT)
```
POST /ifttt/bill/create
```

Create a bill from IFTTT webhook (form-encoded, not JSON).

**Request Body (form-encoded):**
```
name=Electricity+Bill&amount=150.00&due_date=2024-02-01&category=Utilities
```

**Response:**
```json
{
  "success": true,
  "message": "Bill created"
}
```

---

### Utility

#### Health Check
```
GET /health
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:00:00Z",
  "version": "1.0.0",
  "billsCount": 24,
  "household": true
}
```

#### OpenAPI Spec
```
GET /openapi.json
```

Returns the OpenAPI 3.0 specification for this API.

---

## Testing with cURL

### List Bills
```bash
curl http://localhost:8765/bills \
  -H "X-API-Key: YOUR_API_KEY"
```

### Create Bill
```bash
curl -X POST http://localhost:8765/bills \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "name": "Internet",
    "amountCents": 7999,
    "currency": "USD",
    "dueDay": 20,
    "dueDate": "2024-02-20T00:00:00Z",
    "recurrence": "Monthly",
    "category": "Phone/Internet"
  }'
```

### Get Summary
```bash
curl http://localhost:8765/summary \
  -H "X-API-Key: YOUR_API_KEY"
```

### Test Webhook
```bash
curl -X POST http://localhost:8765/webhooks/zapier \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "triggerType": "bill_due",
    "eventId": "test_event"
  }'
```

### Create Bill via Webhook
```bash
curl -X POST http://localhost:8765/webhooks/bill/create \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "name": "Zapier Test Bill",
    "amount": 99.99,
    "due_date": "2024-03-01",
    "category": "Other"
  }'
```

### IFTTT Create Bill (Form-encoded)
```bash
curl -X POST http://localhost:8765/ifttt/bill/create \
  -H "X-API-Key: YOUR_API_KEY" \
  -d "name=IFTTT+Bill&amount=50.00&due_date=2024-03-15&category=Utilities"
```

---

## Postman Collection

```json
{
  "info": {
    "name": "Chronicle API",
    "version": "1.0.0"
  },
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:8765"
    },
    {
      "key": "apiKey",
      "value": "YOUR_API_KEY"
    }
  ],
  "item": [
    {
      "name": "List Bills",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/bills",
        "header": [
          {
            "key": "X-API-Key",
            "value": "{{apiKey}}"
          }
        ]
      }
    },
    {
      "name": "Get Summary",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/summary",
        "header": [
          {
            "key": "X-API-Key",
            "value": "{{apiKey}}"
          }
        ]
      }
    },
    {
      "name": "Create Bill",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/bills",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "X-API-Key",
            "value": "{{apiKey}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"name\": \"Test Bill\",\n  \"amountCents\": 1000,\n  \"dueDay\": 15,\n  \"dueDate\": \"2024-02-15T00:00:00Z\",\n  \"category\": \"Other\"\n}"
        }
      }
    },
    {
      "name": "Webhook - Zapier Trigger",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/webhooks/zapier",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "X-API-Key",
            "value": "{{apiKey}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"triggerType\": \"bill_due\",\n  \"eventId\": \"test_123\"\n}"
        }
      }
    },
    {
      "name": "Webhook - Create Bill",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/webhooks/bill/create",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "X-API-Key",
            "value": "{{apiKey}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"name\": \"Zapier Bill\",\n  \"amount\": 49.99,\n  \"due_date\": \"2024-03-01\",\n  \"category\": \"Subscriptions\"\n}"
        }
      }
    }
  ]
}
```

---

## Rate Limits

- **60 requests per minute** per client IP
- Returns `429 Too Many Requests` when exceeded
- No rate limit on `/health` endpoint

## Error Responses

```json
{
  "error": "Error message description"
}
```

| Status Code | Meaning |
|-------------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized (invalid API key) |
| 404 | Not Found |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |
