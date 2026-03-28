import Foundation

// MARK: - Bill Prediction Result

struct BillPredictionResult {
    /// The predicted date when the user will pay this bill.
    let predictedPaymentDate: Date

    /// Confidence score from 0.0 to 1.0 indicating how reliable the prediction is.
    /// Higher values mean more historical data and consistent payment patterns.
    let confidence: Double

    /// The average number of days the user pays before/after the due date.
    /// Negative = early, Positive = late.
    let averageOffsetDays: Double

    /// Number of payment records used in the prediction.
    let recordsUsed: Int
}

// MARK: - Bill Prediction Model

/// On-device prediction model that uses historical payment timing to predict
/// when the user will likely pay a given bill.
///
/// Uses a weighted moving average of past payment timing offsets from the due date,
/// giving more weight to recent payments.
final class BillPredictionModel {
    static let shared = BillPredictionModel()

    private init() {}

    // MARK: - Public API

    /// Predicts when the user will pay the given bill based on payment history.
    ///
    /// - Parameters:
    ///   - bill: The bill to predict payment for.
    ///   - paymentHistory: Historical payment records for this bill.
    /// - Returns: A `BillPredictionResult` with the predicted date and confidence score.
    func predictPaymentDate(for bill: Bill, paymentHistory: [PaymentRecord]) -> BillPredictionResult {
        // Filter to only completed (paid) records for this bill
        let relevantRecords = paymentHistory
            .filter { $0.billId == bill.id }
            .sorted { $0.paidAt < $1.paidAt }

        let recordsUsed = relevantRecords.count

        // Not enough data — use due date as fallback with low confidence
        guard recordsUsed >= 1 else {
            return BillPredictionResult(
                predictedPaymentDate: bill.dueDate,
                confidence: 0.0,
                averageOffsetDays: 0,
                recordsUsed: 0
            )
        }

        // Calculate payment offset from due date for each record
        // Offset = paidAt - dueDate (in days)
        // Positive = paid late, Negative = paid early
        let calendar = Calendar.current
        let offsets: [Double] = relevantRecords.compactMap { record in
            let components = calendar.dateComponents([.day], from: bill.dueDate, to: record.paidAt)
            return components.day.map { Double($0) }
        }

        guard !offsets.isEmpty else {
            return BillPredictionResult(
                predictedPaymentDate: bill.dueDate,
                confidence: 0.0,
                averageOffsetDays: 0,
                recordsUsed: recordsUsed
            )
        }

        // Compute weighted moving average of offsets (more recent = higher weight)
        let weightedOffset = computeWeightedMovingAverage(values: offsets)
        let confidence = computeConfidence(offsets: offsets, recordCount: recordsUsed)

        // Predicted payment date = due date + weighted offset
        let daysToAdd = Int(weightedOffset.rounded())
        let predictedDate = calendar.date(byAdding: .day, value: daysToAdd, to: bill.dueDate) ?? bill.dueDate

        return BillPredictionResult(
            predictedPaymentDate: predictedDate,
            confidence: confidence,
            averageOffsetDays: weightedOffset,
            recordsUsed: recordsUsed
        )
    }

    // MARK: - Weighted Moving Average

    /// Computes an exponentially weighted moving average of payment offsets.
    /// More recent payments receive higher weight.
    ///
    /// Uses exponential decay: weight_i = decay^(n-i) where n is total count
    /// and decay = 0.7 (recent payments weighted more heavily).
    private func computeWeightedMovingAverage(values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let decay = 0.7
        var weightedSum = 0.0
        var totalWeight = 0.0
        let n = values.count

        for (index, value) in values.enumerated() {
            // Most recent = index n-1 gets weight decay^0 = 1
            // Oldest = index 0 gets weight decay^(n-1)
            let weight = pow(decay, Double(n - 1 - index))
            weightedSum += value * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        return weightedSum / totalWeight
    }

    // MARK: - Confidence Score

    /// Computes a confidence score between 0.0 and 1.0 based on:
    /// - Number of historical records (more records = higher confidence)
    /// - Consistency of payment timing (lower variance = higher confidence)
    private func computeConfidence(offsets: [Double], recordCount: Int) -> Double {
        guard !offsets.isEmpty else { return 0 }

        // Base confidence from record count (logarithmic scaling, maxes out at ~10 records)
        let countScore = min(1.0, log(Double(recordCount + 1)) / log(11.0))

        // Consistency score from variance
        // Standard deviation in days; lower = more consistent
        let mean = offsets.reduce(0, +) / Double(offsets.count)
        let variance = offsets.map { pow($0 - mean, 2) }.reduce(0, +) / Double(offsets.count)
        let stdDev = sqrt(variance)

        // Map stdDev to 0-1 range; 0 stdDev = 1.0, 30+ days = 0.0
        let stdDevScore = max(0, 1.0 - (stdDev / 30.0))

        // Combine scores with weighting
        let confidence = (countScore * 0.4) + (stdDevScore * 0.6)
        return min(1.0, max(0.0, confidence))
    }

    // MARK: - Batch Prediction

    /// Predicts payment dates for multiple bills at once.
    func predictAll(bills: [Bill], paymentHistory: [PaymentRecord]) -> [UUID: BillPredictionResult] {
        var results: [UUID: BillPredictionResult] = [:]
        for bill in bills {
            results[bill.id] = predictPaymentDate(for: bill, paymentHistory: paymentHistory)
        }
        return results
    }
}

// MARK: - Payment Timing Insights

extension BillPredictionModel {

    /// Returns a human-readable description of the user's payment habit for a bill.
    func paymentHabitDescription(for bill: Bill, paymentHistory: [PaymentRecord]) -> String {
        let result = predictPaymentDate(for: bill, paymentHistory: paymentHistory)

        guard result.recordsUsed > 0 else {
            return "Not enough payment history to determine habit."
        }

        let offset = result.averageOffsetDays

        if abs(offset) < 1 {
            return "Typically pays right on the due date."
        } else if offset < 0 {
            let days = Int(abs(offset))
            return "Typically pays about \(days) day\(days == 1 ? "" : "s") early."
        } else {
            let days = Int(offset)
            return "Typically pays about \(days) day\(days == 1 ? "" : "s") late."
        }
    }

    /// Returns all bills sorted by how likely they are to be overdue (based on prediction).
    func billsSortedByOverdueRisk(bills: [Bill], paymentHistory: [PaymentRecord]) -> [Bill] {
        let predictions = predictAll(bills: bills, paymentHistory: paymentHistory)

        return bills
            .filter { !$0.isPaid }
            .sorted { bill1, bill2 in
                guard let pred1 = predictions[bill1.id],
                      let pred2 = predictions[bill2.id] else {
                    return false
                }
                return pred1.predictedPaymentDate > pred2.predictedPaymentDate
            }
    }
}
