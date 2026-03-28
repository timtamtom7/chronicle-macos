# Webhook Integration Guide

Chronicle supports webhooks for automation platforms like Zapier, Make (Integromat), and IFTTT.

## Webhook URLs

```
http://localhost:8765/webhooks/zapier
http://localhost:8765/webhooks/bill/create
http://localhost:8765/ifttt/bills/due
http://localhost:8765/ifttt/bill/create
```

## Zapier / Make Integration

### Endpoint: `POST /webhooks/zapier`

Receives trigger events from Zapier/Make. Use this to notify Chronicle when external events occur (e.g., calendar events, emails).

**Request Body (JSON):**
```json
{
  "triggerType": "bill_due",
  "eventId": "evt_123",
  "timestamp": "2024-01-15T10:00:00Z"
}
```

**Supported Trigger Types:**
- `bill_due` - Triggered when a bill becomes due (Zapier detects via calendar)
- `reminder` - Custom reminder events

**Response:**
```json
{
  "success": true,
  "message": "Webhook received"
}
```

### Endpoint: `POST /webhooks/bill/create`

Create a bill directly from Zapier/Make automation.

**Request Body (JSON):**
```json
{
  "name": "Electricity Bill",
  "amount": 150.00,
  "due_date": "2024-02-01",
  "category": "Utilities",
  "currency": "USD",
  "notes": "Monthly electricity",
  "recurrence": "Monthly"
}
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Bill name |
| amount | number | Yes | Bill amount (dollars, not cents) |
| due_date | string | Yes | Due date (ISO8601: YYYY-MM-DD) |
| category | string | No | Category (Housing, Utilities, Subscriptions, etc.) |
| currency | string | No | Currency code (USD, EUR, GBP, etc.) |
| notes | string | No | Optional notes |
| recurrence | string | No | None, Weekly, Monthly, Quarterly, etc. |

**Response:**
```json
{
  "success": true,
  "message": "Bill created",
  "billId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## IFTTT Integration

IFTTT uses form-encoded bodies (`key=value`), not JSON. Chronicle handles both formats.

### Endpoint: `GET /ifttt/bills/due`

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

### Endpoint: `POST /ifttt/bill/create`

Create a bill from IFTTT webhook (form-encoded).

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

## Zapier Setup Example

### Trigger: Bill Due Date

1. In Zapier, create a **Calendar** trigger (e.g., Google Calendar)
2. Filter for events containing "due" in the title
3. Add a **Webhook** step with:
   - **Method:** POST
   - **URL:** `http://YOUR_MAC_IP:8765/webhooks/zapier`
   - **Data:**

```json
{
  "triggerType": "bill_due",
  "eventId": "{{calendar_event_id}}",
  "timestamp": "{{calendar_event_time}}"
}
```

### Action: Create Bill

1. Trigger on your desired event
2. Add a **Webhook** action with:
   - **Method:** POST
   - **URL:** `http://YOUR_MAC_IP:8765/webhooks/bill/create`
   - **Data:**

```json
{
  "name": "{{bill_name}}",
  "amount": {{bill_amount}},
  "due_date": "{{due_date}}",
  "category": "{{category}}"
}
```

## Authentication

All webhook endpoints require the Chronicle API key:

- **Header:** `Authorization: Bearer YOUR_API_KEY`
- **Header:** `X-API-Key: YOUR_API_KEY`

Generate/manage your API key in Chronicle's API Settings.

## Rate Limits

- 60 requests per minute per client IP
- Returns `429 Too Many Requests` when exceeded
