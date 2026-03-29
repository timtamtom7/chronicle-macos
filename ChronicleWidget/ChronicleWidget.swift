import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Bundle

@main
struct ChronicleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChronicleWidget()
        ChronicleBillsDueWidget()
        ChronicleSpendingWidget()
        BusinessExpenseWidget()
        TaxDeductibleWidget()
        BusinessUpcomingWidget()
        MonthlyCalendarWidget()
        FundWidget()
        InteractivePayWidget()
    }
}

// MARK: - Widget Entry

struct ChronicleEntry: TimelineEntry {
    let date: Date
    let bills: [BillSnapshot]
    let monthlyTotal: Double
    let nextBillDue: BillSnapshot?
    let selectedBillId: UUID?
}

struct BillSnapshot: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDate: Date
    let isPaid: Bool
    let category: String
    let isTaxDeductible: Bool
    let businessCategory: String
}

// MARK: - Business Widget Entry

struct BusinessEntry: TimelineEntry {
    let date: Date
    let monthlyBusinessTotal: Double
    let lastMonthTotal: Double
    let quarterlyDeductibleTotal: Double
    let upcomingBusinessBills: [BillSnapshot]
    let topTaxCategories: [(category: String, total: Double)]
}

// MARK: - Timeline Provider (Shared)

struct ChronicleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChronicleEntry {
        ChronicleEntry(
            date: Date(),
            bills: [],
            monthlyTotal: 0,
            nextBillDue: nil,
            selectedBillId: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ChronicleEntry) -> Void) {
        let entry = loadEntry(selectedBillId: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChronicleEntry>) -> Void) {
        let entry = loadEntry(selectedBillId: nil)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry(selectedBillId: UUID?) -> ChronicleEntry {
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard

        var bills: [BillSnapshot] = []
        var monthlyTotal: Double = 0
        var nextBillDue: BillSnapshot?

        let businessInfo = loadBusinessInfo(from: defaults)

        if let data = defaults.data(forKey: "widget_bills"),
           let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {
            bills = decoded.map { bill in
                let info = businessInfo[bill.id]
                return BillSnapshot(
                    id: bill.id,
                    name: bill.name,
                    amount: bill.amount,
                    dueDate: bill.dueDate,
                    isPaid: bill.isPaid,
                    category: bill.category,
                    isTaxDeductible: info?.isTaxDeductible ?? false,
                    businessCategory: info?.businessCategory.rawValue ?? ""
                )
            }

            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

            monthlyTotal = bills
                .filter { $0.isPaid && $0.dueDate >= startOfMonth && $0.dueDate <= now }
                .reduce(0) { $0 + (($1.amount as NSDecimalNumber).doubleValue) }

            let upcoming = bills
                .filter { !$0.isPaid && $0.dueDate >= calendar.startOfDay(for: now) }
                .sorted { $0.dueDate < $1.dueDate }
            nextBillDue = upcoming.first
        }

        return ChronicleEntry(date: Date(), bills: bills, monthlyTotal: monthlyTotal, nextBillDue: nextBillDue, selectedBillId: selectedBillId)
    }

    private func loadBusinessInfo(from defaults: UserDefaults) -> [UUID: BusinessBillInfo] {
        if let data = defaults.data(forKey: "widget_business_info"),
           let info = try? JSONDecoder().decode([UUID: BusinessBillInfo].self, from: data) {
            return info
        }
        return [:]
    }
}

// MARK: - Business Widget Provider

struct BusinessWidgetProvider: TimelineProvider {
    typealias Entry = BusinessEntry

    func placeholder(in context: Context) -> BusinessEntry {
        BusinessEntry(
            date: Date(),
            monthlyBusinessTotal: 0,
            lastMonthTotal: 0,
            quarterlyDeductibleTotal: 0,
            upcomingBusinessBills: [],
            topTaxCategories: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BusinessEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BusinessEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> BusinessEntry {
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard

        var allBills: [BillSnapshot] = []
        var monthlyBusinessTotal: Double = 0
        var lastMonthTotal: Double = 0
        var quarterlyDeductibleTotal: Double = 0
        var upcomingBusinessBills: [BillSnapshot] = []
        var categoryTotals: [String: Double] = [:]

        let businessInfo = loadBusinessInfo(from: defaults)

        if let data = defaults.data(forKey: "widget_bills"),
           let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {

            let calendar = Calendar.current
            let now = Date()

            allBills = decoded.map { bill in
                let info = businessInfo[bill.id]
                return BillSnapshot(
                    id: bill.id,
                    name: bill.name,
                    amount: bill.amount,
                    dueDate: bill.dueDate,
                    isPaid: bill.isPaid,
                    category: bill.category,
                    isTaxDeductible: info?.isTaxDeductible ?? false,
                    businessCategory: info?.businessCategory.rawValue ?? ""
                )
            }

            // Monthly business total (business-tagged bills this month)
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            monthlyBusinessTotal = allBills
                .filter { bill in
                    !bill.businessCategory.isEmpty &&
                    bill.isPaid &&
                    bill.dueDate >= startOfMonth &&
                    bill.dueDate <= now
                }
                .reduce(0) { $0 + (($1.amount as NSDecimalNumber).doubleValue) }

            // Last month total
            if let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
               let lastMonthEnd = calendar.date(byAdding: .month, value: 1, to: startOfMonth) {
                lastMonthTotal = allBills
                    .filter { bill in
                        !bill.businessCategory.isEmpty &&
                        bill.isPaid &&
                        bill.dueDate >= lastMonthStart &&
                        bill.dueDate < lastMonthEnd
                    }
                    .reduce(0) { $0 + (($1.amount as NSDecimalNumber).doubleValue) }
            }

            // Quarterly deductible total (current quarter)
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let quarterStartMonth = quarter * 3 + 1
            var quarterStartComponents = calendar.dateComponents([.year], from: now)
            quarterStartComponents.month = quarterStartMonth
            quarterStartComponents.day = 1
            let quarterStart = calendar.date(from: quarterStartComponents) ?? now
            let quarterEnd: Date
            if quarterStartMonth <= 3 {
                quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            } else if quarterStartMonth <= 6 {
                quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            } else if quarterStartMonth <= 9 {
                quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            } else {
                quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            }

            let deductibleBills = allBills.filter { bill in
                bill.isTaxDeductible &&
                bill.dueDate >= quarterStart &&
                bill.dueDate < quarterEnd
            }

            quarterlyDeductibleTotal = deductibleBills
                .reduce(0) { $0 + (($1.amount as NSDecimalNumber).doubleValue) }

            // Aggregate by business category
            for bill in deductibleBills {
                let cat = bill.businessCategory.isEmpty ? "Other" : bill.businessCategory
                categoryTotals[cat, default: 0] += (bill.amount as NSDecimalNumber).doubleValue
            }

            // Upcoming business bills (next 3 unpaid with business tag)
            let today = calendar.startOfDay(for: now)
            upcomingBusinessBills = allBills
                .filter { bill in
                    !bill.businessCategory.isEmpty &&
                    !bill.isPaid &&
                    bill.dueDate >= today
                }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(3)
                .map { $0 }
        }

        let topCategories = categoryTotals
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (category: $0.key, total: $0.value) }

        return BusinessEntry(
            date: Date(),
            monthlyBusinessTotal: monthlyBusinessTotal,
            lastMonthTotal: lastMonthTotal,
            quarterlyDeductibleTotal: quarterlyDeductibleTotal,
            upcomingBusinessBills: upcomingBusinessBills,
            topTaxCategories: Array(topCategories)
        )
    }

    private func loadBusinessInfo(from defaults: UserDefaults) -> [UUID: BusinessBillInfo] {
        if let data = defaults.data(forKey: "widget_business_info"),
           let info = try? JSONDecoder().decode([UUID: BusinessBillInfo].self, from: data) {
            return info
        }
        return [:]
    }
}

// MARK: - Select Bill Intent (macOS 14+)
// Keeping for reference; AppIntentConfiguration requires macOS 14+
// MARK: - R18 Calendar Widget Entry

struct CalendarEntry: TimelineEntry {
    let date: Date
    let bills: [BillSnapshot]
    let month: Int
    let year: Int
    let selectedMonth: Int
    let selectedYear: Int
}

// MARK: - R18 Fund Widget Entry

struct FundEntry: TimelineEntry {
    let date: Date
    let spent: Double
    let budget: Double
    let category: String?
}

// MARK: - R18 Interactive Pay Widget Entry

struct InteractivePayEntry: TimelineEntry {
    let date: Date
    let selectedBill: BillSnapshot?
    let allBills: [BillSnapshot]
}



// MARK: - R18 Calendar Widget Provider

struct CalendarWidgetProvider: TimelineProvider {
    typealias Entry = CalendarEntry
    
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), bills: [], month: 0, year: 0, selectedMonth: 0, selectedYear: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        let entry = loadEntry(monthOffset: 0)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        var entries: [CalendarEntry] = []
        for offset in 0..<3 {
            let entry = loadEntry(monthOffset: offset)
            entries.append(entry)
        }
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEntry(monthOffset: Int) -> CalendarEntry {
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard
        let calendar = Calendar.current
        let now = Date()
        
        guard let targetMonth = calendar.date(byAdding: .month, value: -monthOffset, to: now) else {
            return CalendarEntry(date: Date(), bills: [], month: 0, year: 0, selectedMonth: 0, selectedYear: 0)
        }
        
        let month = calendar.component(.month, from: targetMonth)
        let year = calendar.component(.year, from: targetMonth)
        
        var bills: [BillSnapshot] = []
        if let data = defaults.data(forKey: "widget_bills"),
           let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {
            bills = decoded.map { bill in
                BillSnapshot(
                    id: bill.id,
                    name: bill.name,
                    amount: bill.amount,
                    dueDate: bill.dueDate,
                    isPaid: bill.isPaid,
                    category: bill.category,
                    isTaxDeductible: false,
                    businessCategory: ""
                )
            }
        }
        
        return CalendarEntry(date: Date(), bills: bills, month: month, year: year, selectedMonth: month, selectedYear: year)
    }
}

// MARK: - R18 Fund Widget Provider

struct FundWidgetProvider: TimelineProvider {
    typealias Entry = FundEntry
    
    func placeholder(in context: Context) -> FundEntry {
        FundEntry(date: Date(), spent: 1234, budget: 2000, category: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FundEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FundEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEntry() -> FundEntry {
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        var spent: Double = 0
        if let data = defaults.data(forKey: "widget_bills"),
           let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {
            spent = decoded
                .filter { $0.isPaid && $0.dueDate >= startOfMonth && $0.dueDate <= now }
                .reduce(0) { $0 + (($1.amount as NSDecimalNumber).doubleValue) }
        }
        
        let budget = defaults.double(forKey: "monthly_budget")
        
        return FundEntry(date: Date(), spent: spent, budget: budget, category: nil)
    }
}

// MARK: - R18 Interactive Pay Widget Provider

struct InteractivePayWidgetProvider: TimelineProvider {
    typealias Entry = InteractivePayEntry
    
    func placeholder(in context: Context) -> InteractivePayEntry {
        let sampleBill = BillSnapshot(id: UUID(), name: "Netflix", amount: 15.99, dueDate: Date(), isPaid: false, category: "Subscriptions", isTaxDeductible: false, businessCategory: "")
        return InteractivePayEntry(date: Date(), selectedBill: sampleBill, allBills: [sampleBill])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (InteractivePayEntry) -> Void) {
        let entry = loadEntry(billName: nil)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<InteractivePayEntry>) -> Void) {
        let entry = loadEntry(billName: nil)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEntry(billName: String?) -> InteractivePayEntry {
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        
        var allBills: [BillSnapshot] = []
        if let data = defaults.data(forKey: "widget_bills"),
           let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {
            allBills = decoded.map { bill in
                BillSnapshot(
                    id: bill.id,
                    name: bill.name,
                    amount: bill.amount,
                    dueDate: bill.dueDate,
                    isPaid: bill.isPaid,
                    category: bill.category,
                    isTaxDeductible: false,
                    businessCategory: ""
                )
            }
        }
        
        let upcoming = allBills.filter { !$0.isPaid && $0.dueDate >= now }.sorted { $0.dueDate < $1.dueDate }
        
        let selected: BillSnapshot?
        if let name = billName {
            selected = upcoming.first { $0.name.localizedCaseInsensitiveContains(name) }
        } else {
            selected = upcoming.first
        }
        
        return InteractivePayEntry(date: Date(), selectedBill: selected, allBills: upcoming)
    }
}

// struct BillEntity: AppEntity { ... }
// struct BillEntityQuery: EntityQuery { ... }

// MARK: - Widget Bill (Codable for sharing)

struct WidgetBill: Codable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDate: Date
    let isPaid: Bool
    let category: String
}

// MARK: - Business Bill Info (Codable for sharing)

struct BusinessBillInfo: Codable {
    var isTaxDeductible: Bool
    var businessCategory: BusinessCategory
    var isReimbursable: Bool

    init(
        isTaxDeductible: Bool = false,
        businessCategory: BusinessCategory = .other,
        isReimbursable: Bool = false
    ) {
        self.isTaxDeductible = isTaxDeductible
        self.businessCategory = businessCategory
        self.isReimbursable = isReimbursable
    }
}

// MARK: - Helper to load all bills (shared)

private func loadAllBills() -> [BillSnapshot] {
    let defaults = UserDefaults(suiteName: "group.com.chronicle.macos") ?? .standard
    var bills: [BillSnapshot] = []
    if let data = defaults.data(forKey: "widget_bills"),
       let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) {
        bills = decoded.map { bill in
            BillSnapshot(
                id: bill.id,
                name: bill.name,
                amount: bill.amount,
                dueDate: bill.dueDate,
                isPaid: bill.isPaid,
                category: bill.category,
                isTaxDeductible: false,
                businessCategory: ""
            )
        }
    }
    return bills
}

enum BusinessCategory: String, CaseIterable, Codable, Identifiable {
    case office = "Office"
    case software = "Software"
    case utilities = "Utilities"
    case travel = "Travel"
    case meals = "Meals & Entertainment"
    case equipment = "Equipment"
    case marketing = "Marketing"
    case professional = "Professional Services"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .office: return "building.2.fill"
        case .software: return "laptopcomputer"
        case .utilities: return "bolt.fill"
        case .travel: return "airplane"
        case .meals: return "fork.knife"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .marketing: return "megaphone.fill"
        case .professional: return "briefcase.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
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

            VStack(alignment: .leading, spacing: 4) {
                Text("THIS MONTH")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("$\(entry.monthlyTotal, specifier: "%.2f")")
                    .font(.system(size: 32, weight: .bold))
            }

            Divider()

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

// MARK: - Business Expense Widget (systemSmall)

struct BusinessExpenseWidget: Widget {
    let kind: String = "BusinessExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusinessWidgetProvider()) { entry in
            BusinessExpenseWidgetView(entry: entry)
        }
        .configurationDisplayName("Business Expenses")
        .description("Track your monthly business expenses")
        .supportedFamilies([.systemSmall])
    }
}

struct BusinessExpenseWidgetView: View {
    let entry: BusinessEntry

    private let businessAccent = Color(red: 0.13, green: 0.59, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(businessAccent)
                Text("Business")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Total")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("$\(entry.monthlyBusinessTotal, specifier: "%.2f")")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            changePercentageView
        }
        .padding()
    }

    @ViewBuilder
    private var changePercentageView: some View {
        let change = percentageChange
        HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text("\(abs(change), specifier: "%.0f")%")
                .font(.caption)
                .fontWeight(.medium)
            Text("vs last month")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .foregroundColor(change >= 0 ? .red : .green)
    }

    private var percentageChange: Double {
        guard entry.lastMonthTotal > 0 else { return 0 }
        return ((entry.monthlyBusinessTotal - entry.lastMonthTotal) / entry.lastMonthTotal) * 100
    }
}

// MARK: - Tax Deductible Widget (systemMedium)

struct TaxDeductibleWidget: Widget {
    let kind: String = "TaxDeductibleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusinessWidgetProvider()) { entry in
            TaxDeductibleWidgetView(entry: entry)
        }
        .configurationDisplayName("Tax Deductible")
        .description("Quarterly tax-deductible expenses")
        .supportedFamilies([.systemMedium])
    }
}

struct TaxDeductibleWidgetView: View {
    let entry: BusinessEntry

    private let businessAccent = Color(red: 0.13, green: 0.59, blue: 0.95)
    private let annualDeductibleGoal: Double = 10_000

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(businessAccent)
                    Text("Q\(currentQuarter) Tax Deductible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("$\(entry.quarterlyDeductibleTotal, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                progressBar

                Text("Goal: $\(annualDeductibleGoal, specifier: "%.0f")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("TOP CATEGORIES")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if entry.topTaxCategories.isEmpty {
                    Text("No deductions yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(entry.topTaxCategories.prefix(3), id: \.category) { item in
                        HStack {
                            Circle()
                                .fill(businessAccent)
                                .frame(width: 6, height: 6)
                            Text(item.category)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("$\(item.total, specifier: "%.0f")")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }

                Spacer()

                Link(destination: URL(string: "chronicle://export/tax")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2)
                        Text("Export")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(businessAccent.opacity(0.15))
                    .foregroundColor(businessAccent)
                    .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private var progressBar: some View {
        let progress = min(entry.quarterlyDeductibleTotal / annualDeductibleGoal, 1.0)
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(businessAccent)
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }

    private var currentQuarter: Int {
        let month = Calendar.current.component(.month, from: Date())
        return (month - 1) / 3 + 1
    }
}

// MARK: - Business Upcoming Widget (systemMedium)

struct BusinessUpcomingWidget: Widget {
    let kind: String = "BusinessUpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusinessWidgetProvider()) { entry in
            BusinessUpcomingWidgetView(entry: entry)
        }
        .configurationDisplayName("Business Bills")
        .description("Upcoming business-tagged bills")
        .supportedFamilies([.systemMedium])
    }
}

struct BusinessUpcomingWidgetView: View {
    let entry: BusinessEntry

    private let businessAccent = Color(red: 0.13, green: 0.59, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(businessAccent)
                Text("Business Bills")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Business only")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(businessAccent.opacity(0.15))
                    .foregroundColor(businessAccent)
                    .cornerRadius(4)
            }

            Divider()

            if entry.upcomingBusinessBills.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("No business bills")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.upcomingBusinessBills) { bill in
                    HStack {
                        Rectangle()
                            .fill(businessAccent)
                            .frame(width: 3, height: 32)
                            .cornerRadius(1.5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Text(bill.businessCategory)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\((bill.amount as NSDecimalNumber).doubleValue, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: bill.dueDate).day ?? 0
                            Text(days == 0 ? "Today" : "\(days)d")
                                .font(.caption2)
                                .foregroundColor(days <= 3 ? .orange : .secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}
import Foundation
import AppIntents

// MARK: - Monthly Calendar Widget (systemLarge)

struct MonthlyCalendarWidget: Widget {
    let kind: String = "MonthlyCalendarWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            MonthlyCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Monthly Calendar")
        .description("Full month calendar with bill due dates")
        .supportedFamilies([.systemLarge])
    }
}

struct MonthlyCalendarWidgetView: View {
    let entry: CalendarEntry
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(monthYearString)
                    .font(.headline)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
            }
            
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        CalendarDayView(
                            day: day,
                            bills: billsForDay(day),
                            isToday: isToday(day),
                            isPaid: isPaid(day)
                        )
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var monthYearString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        var components = DateComponents()
        components.year = entry.year
        components.month = entry.month
        components.day = 1
        if let date = calendar.date(from: components) {
            return dateFormatter.string(from: date)
        }
        return ""
    }
    
    private var calendarDays: [Int?] {
        var components = DateComponents()
        components.year = entry.year
        components.month = entry.month
        components.day = 1
        
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = firstWeekday - 1
        
        var days: [Int?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            days.append(day)
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func billsForDay(_ day: Int) -> [BillSnapshot] {
        var components = DateComponents()
        components.year = entry.year
        components.month = entry.month
        components.day = day
        guard let dayDate = calendar.date(from: components) else { return [] }
        let startOfDay = calendar.startOfDay(for: dayDate)
        
        return entry.bills.filter { bill in
            calendar.isDate(bill.dueDate, inSameDayAs: startOfDay)
        }
    }
    
    private func isToday(_ day: Int) -> Bool {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        return components.day == day && components.month == entry.month && components.year == entry.year
    }
    
    private func isPaid(_ day: Int) -> Bool {
        let bills = billsForDay(day)
        return !bills.isEmpty && bills.allSatisfy { $0.isPaid }
    }
}

struct CalendarDayView: View {
    let day: Int
    let bills: [BillSnapshot]
    let isToday: Bool
    let isPaid: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .white : (isPaid ? .secondary : .primary))
                .frame(width: 24, height: 24)
                .background(isToday ? Color.accentColor : Color.clear)
                .cornerRadius(12)
            
            if !bills.isEmpty {
                HStack(spacing: 1) {
                    ForEach(bills.prefix(3).indices, id: \.self) { _ in
                        Circle()
                            .fill(bills[0].isPaid ? Color.green : Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28)
    }
}

// MARK: - Fund Widget (systemMedium)

struct FundWidget: Widget {
    let kind: String = "FundWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FundWidgetProvider()) { entry in
            FundWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Tracker")
        .description("Track spending vs monthly budget")
        .supportedFamilies([.systemMedium])
    }
}

struct FundWidgetView: View {
    let entry: FundEntry
    
    private var progress: Double {
        guard entry.budget > 0 else { return 0 }
        return min(entry.spent / entry.budget, 1.0)
    }
    
    private var progressColor: Color {
        if progress >= 0.9 {
            return .red
        } else if progress >= 0.75 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Budget")
                    .font(.headline)
                Spacer()
                Text(monthString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(entry.spent, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold))
                
                Text("of $\(entry.budget, specifier: "%.2f") spent")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 16)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 2, height: 20)
                        .offset(x: geometry.size.width - 1)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 16)
                }
            }
            .frame(height: 20)
            
            HStack {
                Text("\(Int(progress * 100))% of budget used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if progress >= 0.9 {
                    Label("Over limit", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if progress >= 0.75 {
                    Label("Nearing limit", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Interactive Pay Widget (systemSmall with Button - macOS 14+)

struct InteractivePayWidget: Widget {
    let kind: String = "InteractivePayWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InteractivePayWidgetProvider()) { entry in
            InteractivePayWidgetView(entry: entry)
        }
        .configurationDisplayName("Pay Bill")
        .description("Quickly mark a bill as paid directly from the widget")
        .supportedFamilies([.systemSmall])
    }
}

struct InteractivePayWidgetView: View {
    let entry: InteractivePayEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Chronicle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            if let bill = entry.selectedBill {
                Text(bill.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("$\((bill.amount as NSDecimalNumber).doubleValue, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: bill.dueDate).day ?? 0
                Text(days == 0 ? "Due today" : "Due in \(days)d")
                    .font(.caption)
                    .foregroundColor(days <= 3 ? .orange : .secondary)
                
                Spacer()
                
                if #available(macOS 14.0, *) {
                    Button(intent: MarkBillFromWidgetIntent(billId: bill.id.uuidString)) {
                        Text("Pay")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Open app to pay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }
            } else {
                Text("No bills due")
                    .font(.headline)
                Text("All caught up!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Mark Bill From Widget Intent

@available(macOS 13.0, *)
struct MarkBillFromWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Bill as Paid from Widget"
    static var description = IntentDescription("Marks a bill as paid from the widget")
    
    @Parameter(title: "Bill ID")
    var billId: String
    
    init() {}
    
    init(billId: String) {
        self.billId = billId
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: billId) else {
            return .result()
        }
        
        let defaults = UserDefaults(suiteName: "group.com.chronicle.macos")
        if var bills = loadWidgetBills(from: defaults) {
            if let index = bills.firstIndex(where: { $0.id == uuid && !$0.isPaid }) {
                var bill = bills[index]
                bill = WidgetBill(id: bill.id, name: bill.name, amount: bill.amount, dueDate: bill.dueDate, isPaid: true, category: bill.category)
                bills[index] = bill
                saveWidgetBills(bills, to: defaults)
            }
        }
        
        return .result()
    }
    
    private func loadWidgetBills(from defaults: UserDefaults?) -> [WidgetBill]? {
        guard let defaults = defaults,
              let data = defaults.data(forKey: "widget_bills"),
              let decoded = try? JSONDecoder().decode([WidgetBill].self, from: data) else {
            return nil
        }
        return decoded
    }
    
    private func saveWidgetBills(_ bills: [WidgetBill], to defaults: UserDefaults?) {
        guard let defaults = defaults,
              let encoded = try? JSONEncoder().encode(bills) else { return }
        defaults.set(encoded, forKey: "widget_bills")
    }
}


