import Foundation

final class ExchangeRateService {
    static let shared = ExchangeRateService()

    private let ratesKey = "cachedExchangeRates"
    private let timestampKey = "exchangeRatesTimestamp"
    private let lastFetchKey = "exchangeRatesLastFetch"

    private(set) var rates: [String: Double] = [:]
    private(set) var lastUpdated: Date?

    private init() {
        loadCachedRates()
    }

    var baseURL: URL? {
        URL(string: "https://api.exchangerate.host/latest?base=USD")
    }

    func fetchRates() async throws {
        guard let url = baseURL else { return }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExchangeRateError.fetchFailed
        }

        struct ExchangeResponse: Decodable {
            let success: Bool?
            let rates: [String: Double]?

            enum CodingKeys: String, CodingKey {
                case success, rates
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.success = try? container.decode(Bool.self, forKey: .success)
                self.rates = try? container.decode([String: Double].self, forKey: .rates)
            }
        }

        let decoded = try JSONDecoder().decode(ExchangeResponse.self, from: data)

        guard let fetchedRates = decoded.rates, !fetchedRates.isEmpty else {
            throw ExchangeRateError.invalidResponse
        }

        self.rates = fetchedRates
        self.lastUpdated = Date()
        saveCachedRates()
    }

    func fetchRatesIfNeeded() async {
        let now = Date()
        let calendar = Calendar.current

        if let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date {
            let hoursSinceLastFetch = calendar.dateComponents([.hour], from: lastFetch, to: now).hour ?? 0
            if hoursSinceLastFetch < 24 { return }
        }

        do {
            try await fetchRates()
        } catch {
            print("Exchange rate fetch failed: \(error)")
        }
    }

    func convert(_ amount: Decimal, from: Currency, to: Currency) -> Decimal? {
        if from == to { return amount }

        guard let fromRate = rates[from.rawValue],
              let toRate = rates[to.rawValue],
              fromRate > 0 else { return nil }

        let amountUSD = NSDecimalNumber(decimal: amount).doubleValue / fromRate
        let converted = amountUSD * toRate
        return Decimal(converted)
    }

    private func loadCachedRates() {
        if let data = UserDefaults.standard.data(forKey: ratesKey),
           let cached = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.rates = cached
        }

        if let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date {
            self.lastUpdated = timestamp
        }

        if rates.isEmpty {
            rates = defaultRates
        }
    }

    private func saveCachedRates() {
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: ratesKey)
        }
        UserDefaults.standard.set(lastUpdated, forKey: timestampKey)
        UserDefaults.standard.set(Date(), forKey: lastFetchKey)
    }

    private var defaultRates: [String: Double] {
        [
            "USD": 1.0,
            "EUR": 0.92,
            "GBP": 0.79,
            "CAD": 1.36,
            "AUD": 1.53,
            "JPY": 149.5,
            "CHF": 0.88,
            "INR": 83.1,
            "BRL": 4.97,
            "MXN": 17.15
        ]
    }
}

enum ExchangeRateError: Error {
    case fetchFailed
    case invalidResponse
}
