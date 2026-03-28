import Foundation

/// ZapierService handles incoming webhooks from Zapier/Make automation platform
/// and integrates with Chronicle's bill management system.
@MainActor
final class ZapierService: ObservableObject {
    static let shared = ZapierService()

    private init() {}

    // MARK: - Webhook Payloads

    struct WebhookPayload: Codable {
        let triggerType: String?
        let eventId: String?
        let timestamp: Date?
    }

    struct CreateBillPayload: Codable {
        let name: String
        let amount: Double
        let dueDate: String // ISO8601 format
        let category: String?
        let currency: String?
        let notes: String?
        let recurrence: String?

        enum CodingKeys: String, CodingKey {
            case name
            case amount
            case dueDate = "due_date"
            case category
            case currency
            case notes
            case recurrence
        }
    }

    // MARK: - Webhook Processing

    /// Process an incoming Zapier webhook trigger
    /// Zapier sends events when external triggers fire (e.g., calendar events, emails)
    func processWebhook(data: Data) -> WebhookResult {
        guard let payload = try? JSONDecoder().decode(WebhookPayload.self, from: data) else {
            return WebhookResult(success: false, message: "Invalid webhook payload")
        }

        // Handle different trigger types from Zapier
        switch payload.triggerType {
        case "bill_due":
            return handleBillDueEvent(eventId: payload.eventId)
        case "reminder":
            return handleReminderEvent(eventId: payload.eventId)
        default:
            // Zapier webhooks can carry arbitrary data
            return WebhookResult(success: true, message: "Webhook received")
        }
    }

    /// Create a new bill from Zapier webhook data
    func createBillFromWebhook(data: Data) -> WebhookResult {
        guard let payload = try? JSONDecoder().decode(CreateBillPayload.self, from: data) else {
            return WebhookResult(success: false, message: "Invalid bill payload")
        }

        // Validate required fields
        guard !payload.name.isEmpty else {
            return WebhookResult(success: false, message: "Bill name is required")
        }

        guard payload.amount > 0 else {
            return WebhookResult(success: false, message: "Bill amount must be positive")
        }

        // Parse due date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        guard let dueDate = dateFormatter.date(from: payload.dueDate) else {
            return WebhookResult(success: false, message: "Invalid due date format. Use ISO8601 (YYYY-MM-DD)")
        }

        // Create the bill
        let billStore = BillStore.shared
        let amountCents = Int(payload.amount * 100)
        let currency = Currency(rawValue: payload.currency ?? "USD") ?? .usd
        let category = Category(rawValue: payload.category ?? "Other") ?? .other
        let recurrence = Recurrence(rawValue: payload.recurrence ?? "None") ?? .none

        let bill = Bill(
            name: payload.name,
            amountCents: amountCents,
            currency: currency,
            dueDay: Calendar.current.component(.day, from: dueDate),
            dueDate: dueDate,
            recurrence: recurrence,
            category: category,
            notes: payload.notes
        )

        do {
            try billStore.addBill(bill)
            return WebhookResult(
                success: true,
                message: "Bill created successfully",
                data: ["billId": bill.id.uuidString]
            )
        } catch {
            return WebhookResult(success: false, message: "Failed to create bill: \(error.localizedDescription)")
        }
    }

    // MARK: - Event Handlers

    private func handleBillDueEvent(eventId: String?) -> WebhookResult {
        // When Zapier detects a bill is due (e.g., via calendar integration),
        // trigger a local notification in Chronicle for any matching overdue bills.
        let notificationScheduler = NotificationScheduler.shared
        let overdueBills = BillStore.shared.pastDue

        Task {
            for bill in overdueBills.prefix(5) {
                notificationScheduler.sendOverdueNotification(for: bill)
            }
        }

        return WebhookResult(
            success: true,
            message: "Bill due notification triggered",
            data: ["eventId": eventId ?? "unknown"]
        )
    }

    private func handleReminderEvent(eventId: String?) -> WebhookResult {
        // Zapier can trigger custom reminders
        return WebhookResult(
            success: true,
            message: "Reminder event processed",
            data: ["eventId": eventId ?? "unknown"]
        )
    }
}

// MARK: - Webhook Result

struct WebhookResult: Codable {
    let success: Bool
    let message: String
    var data: [String: String]?

    init(success: Bool, message: String, data: [String: String]? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}

// MARK: - IFTTT Support

extension ZapierService {
    /// IFTTT uses form-encoded key=value pairs, not JSON
    /// Parse IFTTT-style webhook body
    func parseIFTTTBody(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        let pairs = body.split(separator: "&")

        for pair in pairs {
            let parts = pair.split(separator: "=")
            if parts.count == 2 {
                let key = parts[0].removingPercentEncoding ?? String(parts[0])
                let value = parts[1].removingPercentEncoding ?? String(parts[1])
                result[key] = value
            }
        }

        return result
    }

    /// Process IFTTT "bills/due" query - returns upcoming bills in IFTTT-friendly format
    func getIFTTTBillsDue() -> Data? {
        let billStore = BillStore.shared
        let upcoming = billStore.upcomingBills

        // IFTTT-friendly JSON format
        let iftttResponse: [String: Any] = [
            "count": upcoming.count,
            "bills": upcoming.map { bill in
                [
                    "name": bill.name,
                    "amount": bill.formattedAmount,
                    "dueDate": ISO8601DateFormatter().string(from: bill.dueDate),
                    "category": bill.category.rawValue
                ]
            }
        ]

        return try? JSONSerialization.data(withJSONObject: iftttResponse)
    }

    /// Create bill from IFTTT webhook (form-encoded)
    func createBillFromIFTTT(_ body: String) -> WebhookResult {
        let params = parseIFTTTBody(body)

        guard let name = params["name"], !name.isEmpty else {
            return WebhookResult(success: false, message: "Name is required")
        }

        guard let amountStr = params["amount"], let amount = Double(amountStr) else {
            return WebhookResult(success: false, message: "Valid amount is required")
        }

        guard let dueDateStr = params["dueDate"] else {
            return WebhookResult(success: false, message: "Due date is required")
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withFullTime]

        var dueDate: Date?
        if let date = dateFormatter.date(from: dueDateStr) {
            dueDate = date
        } else {
            // Try date-only format
            dateFormatter.formatOptions = [.withFullDate]
            dueDate = dateFormatter.date(from: dueDateStr)
        }

        guard let parsedDate = dueDate else {
            return WebhookResult(success: false, message: "Invalid due date format")
        }

        let currency = Currency(rawValue: params["currency"] ?? "USD") ?? .usd
        let category = Category(rawValue: params["category"] ?? "Other") ?? .other

        let bill = Bill(
            name: name,
            amountCents: Int(amount * 100),
            currency: currency,
            dueDay: Calendar.current.component(.day, from: parsedDate),
            dueDate: parsedDate,
            recurrence: .none,
            category: category,
            notes: params["notes"]
        )

        do {
            try BillStore.shared.addBill(bill)
            return WebhookResult(
                success: true,
                message: "Bill created",
                data: ["billId": bill.id.uuidString]
            )
        } catch {
            return WebhookResult(success: false, message: "Failed to create bill")
        }
    }
}
