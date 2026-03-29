# Chronicle Integration Ecosystem

Third-party automation and integration support for Chronicle.

## Overview

Chronicle supports a growing ecosystem of integrations with automation platforms.
These integrations expose bill lifecycle events (due, overdue, paid) as triggers and
allow external systems to create, update, or mark bills as paid.

## Available Integrations

| Platform | Type | Status |
|----------|------|--------|
| Zapier | Trigger + Action | ✅ Planned |
| Make (Integromat) | Trigger + Action | ✅ Planned |
| IFTTT | Trigger | ✅ Planned |

## API Base

All integrations communicate via the Chronicle REST API:

```
POST https://api.chronicle.app/v1/events
Authorization: Bearer <API_KEY>
```

See `docs/api.md` for the full API specification.

---

## Zapier

See `zapier/index.json` for the Zapier app manifest defining:
- **Triggers:** BillDue, BillOverdue, BillPaid
- **Actions:** CreateBill, UpdateBill, MarkBillPaid

## Make (Integromat)

See `make/scenario.json` for the template scenario:
- **Watch Events:** Monitors bill state changes
- **Create Bill:** Adds a new bill from external trigger
- **Send Notification:** Custom notification when bill is due

## IFTTT

See `ifttt/applet.json` for the IFTTT applet definition:
- **Trigger:** BillDue (via Chronicle IFTTT channel)
- **Action:** Any IFTTT action (notification, email, Slack, etc.)
