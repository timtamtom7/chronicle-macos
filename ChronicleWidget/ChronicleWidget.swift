import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct ChronicleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChronicleWidget()
        ChronicleBillsDueWidget()
        ChronicleSpendingWidget()
    }
}

// MARK: - Widget Entry

struct ChronicleEntry: TimelineEntry {
    let date: Date
    let bills: [BillSnapshot]
    let monthlyTotal: Double
    let nextBillDue: BillSnapshot?
}

struct BillSnapshot: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDate: Date
    let isPaid: Bool
    let category: String
}

// MARK: - Timeline Provider

struct ChronicleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChronicleEntry {
        ChronicleEntry(
            date: Date(),
            bills: [],
            monthlyTotal: 0,
            nextBillDue: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ChronicleEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ChronicleEntry>) -> Void) {
        let entry = loadEntry()
        
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadEntry() -> ChronicleEntry {
        // Load from shared UserDefaults (app group)
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard
        
        var bills: [BillSnapshot] = []
        var monthlyTotal: Double = 0
        var nextBillDue: BillSnapshot?
        
        if let data = defaults.data(forKey: "widget_bills"),
           let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {
            bills = decoded.map { WidgetBill in
                BillSnapshot(
                    id: WidgetBill.id,
                    name: WidgetBill.name,
                    amount: WidgetBill.amount,
                    dueDate: WidgetBill.dueDate,
                    isPaid: WidgetBill.isPaid,
                    category: WidgetBill.category
                )
            }
            
            // Calculate monthly total
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            
            monthlyTotal = bills
                .filter { $0.isPaid && $0.dueDate >= startOfMonth && $0.dueDate <= now }
                .reduce(0) { $0 + (($1.amount as NSDecimalNumber).doubleValue) }
            
            // Find next unpaid bill
            let upcoming = bills
                .filter { !$0.isPaid && $0.dueDate >= calendar.startOfDay(for: now) }
                .sorted { $0.dueDate < $1.dueDate }
            nextBillDue = upcoming.first
        }
        
        return ChronicleEntry(date: Date(), bills: bills, monthlyTotal: monthlyTotal, nextBillDue: nextBillDue)
    }
}

// MARK: - Widget Bill (Codable for sharing)

struct WidgetBill: Codable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDate: Date
    let isPaid: Bool
    let category: String
}

// MARK: - Small Widget (Single Bill Countdown)

struct ChronicleWidget: Widget {
    let kind: String = "ChronicleWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChronicleProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Bill")
        .description("Countdown to your next bill")
        .supportedFamilies([.systemSmall])
    }
}

struct SmallWidgetView: View {
    let entry: ChronicleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Chronicle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let next = entry.nextBillDue {
                Text(next.name)
                    .font(.headline)
                    .lineLimit(1)
                
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: next.dueDate).day ?? 0
                Text(days == 0 ? "Due Today" : "\(days) days")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(days <= 3 ? .orange : .primary)
                
                Text("$\((next.amount as NSDecimalNumber).doubleValue, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No bills")
                    .font(.headline)
                Text("All caught up!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Medium Widget (3 Upcoming Bills)

struct ChronicleBillsDueWidget: Widget {
    let kind: String = "ChronicleBillsDueWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChronicleProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Bills")
        .description("Your next 3 upcoming bills")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumWidgetView: View {
    let entry: ChronicleEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Next bill highlight
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let next = entry.nextBillDue {
                    Text(next.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: next.dueDate).day ?? 0
                    Text(days == 0 ? "Today" : "\(days)d")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(days <= 3 ? .orange : .primary)
                    
                    Text("$\((next.amount as NSDecimalNumber).doubleValue, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No bills due")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Right: Next 3 bills
            VStack(alignment: .leading, spacing: 4) {
                Text("UPCOMING")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                let upcoming = entry.bills
                    .filter { !$0.isPaid }
                    .sorted { $0.dueDate < $1.dueDate }
                    .prefix(3)
                
                ForEach(Array(upcoming), id: \.id) { bill in
                    HStack {
                        Text(bill.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("$\((bill.amount as NSDecimalNumber).doubleValue, specifier: "%.0f")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                if upcoming.isEmpty {
                    Text("All caught up!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

// MARK: - Large Widget (Monthly Overview)

struct ChronicleSpendingWidget: Widget {
    let kind: String = "ChronicleSpendingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChronicleProvider()) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Monthly Spending")
        .description("Full monthly overview with spending chart")
        .supportedFamilies([.systemLarge])
    }
}

struct LargeWidgetView: View {
    let entry: ChronicleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Chronicle")
                    .font(.headline)
                Spacer()
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Monthly total
            VStack(alignment: .leading, spacing: 4) {
                Text("THIS MONTH")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("$\(entry.monthlyTotal, specifier: "%.2f")")
                    .font(.system(size: 32, weight: .bold))
            }
            
            Divider()
            
            // Upcoming bills list
            VStack(alignment: .leading, spacing: 6) {
                Text("UPCOMING BILLS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                let upcoming = entry.bills
                    .filter { !$0.isPaid }
                    .sorted { $0.dueDate < $1.dueDate }
                    .prefix(5)
                
                ForEach(Array(upcoming), id: \.id) { bill in
                    HStack {
                        Circle()
                            .fill(categoryColor(for: bill.category))
                            .frame(width: 8, height: 8)
                        Text(bill.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("$\((bill.amount as NSDecimalNumber).doubleValue, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: bill.dueDate).day ?? 0
                        Text(days == 0 ? "Today" : "\(days)d")
                            .font(.caption2)
                            .foregroundColor(days <= 3 ? .orange : .secondary)
                    }
                }
                
                if upcoming.isEmpty {
                    Text("No upcoming bills")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "utilities": return .blue
        case "rent", "mortgage": return .green
        case "subscriptions": return .purple
        case "insurance": return .orange
        default: return .gray
        }
    }
}
