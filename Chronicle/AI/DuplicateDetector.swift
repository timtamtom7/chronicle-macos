import Foundation

/// Detects potential duplicate bills based on name similarity, amount, and date proximity
final class DuplicateDetector {
    static let shared = DuplicateDetector()
    
    private init() {}
    
    /// Result of duplicate detection
    struct DuplicateMatch {
        let existingBill: Bill
        let newBillName: String
        let newAmount: Decimal
        let similarity: Double
        let reasons: [String]
    }
    
    /// Check if a new bill might be a duplicate of an existing one
    /// - Parameters:
    ///   - newBill: The bill being added
    ///   - existingBills: All currently active bills to compare against
    ///   - excludeBillId: Optional bill ID to exclude from comparison (e.g., when editing)
    /// - Returns: A DuplicateMatch if similarity exceeds threshold, nil otherwise
    func checkDuplicate(
        newBillName: String,
        newAmount: Decimal,
        newDueDate: Date,
        currency: Currency,
        existingBills: [Bill],
        excludeBillId: UUID? = nil
    ) -> DuplicateMatch? {
        let threshold = 0.7 // 70% similarity threshold
        
        var bestMatch: DuplicateMatch?
        var bestSimilarity: Double = 0.0
        
        for bill in existingBills {
            guard bill.id != excludeBillId, bill.isActive else { continue }
            
            let similarity = calculateSimilarity(
                bill1Name: bill.name,
                bill1Amount: bill.amount,
                bill1DueDay: bill.dueDay,
                bill2Name: newBillName,
                bill2Amount: newAmount,
                bill2DueDay: Calendar.current.component(.day, from: newDueDate)
            )
            
            if similarity > bestSimilarity && similarity >= threshold {
                bestSimilarity = similarity
                var reasons: [String] = []
                
                if normalizeName(bill.name) == normalizeName(newBillName) {
                    reasons.append("Similar vendor name")
                } else if levenshteinSimilarity(bill.name, newBillName) > 0.8 {
                    reasons.append("Similar vendor name (fuzzy match)")
                }
                
                if bill.amount == newAmount {
                    reasons.append("Same amount")
                } else if bill.amount == newAmount && currency == bill.currency {
                    reasons.append("Same amount and currency")
                }
                
                if abs(bill.dueDay - Calendar.current.component(.day, from: newDueDate)) <= 2 {
                    reasons.append("Similar due date")
                }
                
                if !reasons.isEmpty {
                    bestMatch = DuplicateMatch(
                        existingBill: bill,
                        newBillName: newBillName,
                        newAmount: newAmount,
                        similarity: similarity,
                        reasons: reasons
                    )
                }
            }
        }
        
        return bestMatch
    }
    
    /// Calculate overall similarity score between two potential duplicate bills
    private func calculateSimilarity(
        bill1Name: String,
        bill1Amount: Decimal,
        bill1DueDay: Int,
        bill2Name: String,
        bill2Amount: Decimal,
        bill2DueDay: Int
    ) -> Double {
        // Name similarity (40% weight)
        let nameSim = nameSimilarity(bill1Name, bill2Name) * 0.4
        
        // Amount similarity (40% weight)
        let amountSim = amountSimilarity(bill1Amount, bill2Amount) * 0.4
        
        // Due date proximity (20% weight)
        let dateSim = dateProximitySimilarity(bill1DueDay, bill2DueDay) * 0.2
        
        return nameSim + amountSim + dateSim
    }
    
    /// Similarity between two names using Levenshtein distance and token matching
    private func nameSimilarity(_ name1: String, _ name2: String) -> Double {
        let n1 = normalizeName(name1)
        let n2 = normalizeName(name2)
        
        // Exact match
        if n1 == n2 { return 1.0 }
        
        // Token-based similarity
        let tokens1 = Set(n1.split(separator: " ").map(String.init))
        let tokens2 = Set(n2.split(separator: " ").map(String.init))
        
        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)
        
        if union.isEmpty { return 0 }
        
        let jaccard = Double(intersection.count) / Double(union.count)
        
        // Also consider Levenshtein distance
        let levSim = 1.0 - (Double(levenshteinDistance(n1, n2)) / Double(max(n1.count, n2.count)))
        
        // Combine Jaccard and Levenshtein
        return max(jaccard, levSim * 0.8)
    }
    
    /// Amount similarity — returns 1.0 if equal, 0.5 if within 10%, 0 otherwise
    private func amountSimilarity(_ amount1: Decimal, _ amount2: Decimal) -> Double {
        if amount1 == amount2 { return 1.0 }
        
        let diff = abs(amount1 - amount2)
        let maxAmount = max(abs(amount1), abs(amount2))
        
        if maxAmount == 0 { return 1.0 }
        
        let diffDouble = NSDecimalNumber(decimal: diff).doubleValue
        let maxDouble = NSDecimalNumber(decimal: maxAmount).doubleValue
        let ratio = diffDouble / maxDouble
        
        if ratio <= 0.10 {
            return 1.0 - (ratio * 5) // Scale: 10% diff → 0.5, 0% → 1.0
        }
        
        return 0
    }
    
    /// Date proximity — returns 1.0 if same day, decreasing to 0.3 within a week
    private func dateProximitySimilarity(_ day1: Int, _ day2: Int) -> Double {
        let diff = abs(day1 - day2)
        let normalizedDiff = min(diff, 28) // Cap at ~month
        
        if normalizedDiff == 0 { return 1.0 }
        if normalizedDiff <= 2 { return 0.9 }
        if normalizedDiff <= 5 { return 0.7 }
        if normalizedDiff <= 7 { return 0.5 }
        return 0.3
    }
    
    /// Normalize vendor name for comparison
    private func normalizeName(_ name: String) -> String {
        let lowercase = name.lowercased()
        // Remove common suffixes and prefixes
        let wordsToRemove = ["inc", "llc", "ltd", "corp", "co", "the", "inc.", "llc.", "ltd.", "corp."]
        var result = lowercase
        for word in wordsToRemove {
            result = result.replacingOccurrences(of: word, with: "")
        }
        // Remove non-alphanumeric
        result = result.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Chars = Array(s1)
        let s2Chars = Array(s2)
        let m = s1Chars.count
        let n = s2Chars.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Chars[i-1] == s2Chars[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,       // insertion
                    matrix[i-1][j-1] + cost   // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    /// Levenshtein similarity (0.0 to 1.0)
    private func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let maxLen = max(s1.count, s2.count)
        if maxLen == 0 { return 1.0 }
        let dist = levenshteinDistance(s1, s2)
        return 1.0 - (Double(dist) / Double(maxLen))
    }
}
