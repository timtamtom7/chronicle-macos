import Foundation

final class TemplateService {
    static let shared = TemplateService()
    private let userDefaults = UserDefaults.standard
    private let templatesKey = "billTemplates"

    private init() {}

    // MARK: - CRUD

    func fetchAllTemplates() -> [BillTemplate] {
        guard let data = userDefaults.data(forKey: templatesKey) else { return [] }
        do {
            return try JSONDecoder().decode([BillTemplate].self, from: data)
        } catch {
            print("Failed to decode templates: \(error)")
            return []
        }
    }

    func saveTemplate(_ template: BillTemplate) {
        var templates = fetchAllTemplates()
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        saveTemplates(templates)
    }

    func deleteTemplate(_ templateId: UUID) {
        var templates = fetchAllTemplates()
        templates.removeAll { $0.id == templateId }
        saveTemplates(templates)
    }

    func deleteAllTemplates() {
        userDefaults.removeObject(forKey: templatesKey)
    }

    private func saveTemplates(_ templates: [BillTemplate]) {
        do {
            let data = try JSONEncoder().encode(templates)
            userDefaults.set(data, forKey: templatesKey)
        } catch {
            print("Failed to encode templates: \(error)")
        }
    }

    // MARK: - Template Suggestions

    func suggestTemplateFromExistingBills(_ bills: [Bill]) -> [BillTemplate] {
        var templates: [BillTemplate] = []

        // Group bills by category and recurrence
        var seen: Set<String> = []
        for bill in bills {
            let key = "\(bill.name.lowercased())-\(bill.category.rawValue)-\(bill.recurrence.rawValue)"
            if !seen.contains(key) && bill.recurrence != .none {
                seen.insert(key)
                templates.append(BillTemplate.fromBill(bill))
            }
        }

        return templates
    }

    func duplicateTemplate(_ template: BillTemplate) -> BillTemplate {
        BillTemplate(
            id: UUID(),
            name: "\(template.name) (Copy)",
            amountCents: template.amountCents,
            currency: template.currency,
            dueDay: template.dueDay,
            recurrence: template.recurrence,
            category: template.category,
            notes: template.notes,
            reminderTimings: template.reminderTimings,
            autoMarkPaid: template.autoMarkPaid,
            createdAt: Date()
        )
    }
}
