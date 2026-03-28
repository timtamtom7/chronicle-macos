import Foundation
import NaturalLanguage

/// AI-powered bill categorization engine using NaturalLanguage framework
@MainActor
final class CategorizationEngine {
    static let shared = CategorizationEngine()
    
    private let embedder = NLEmbedder(language: .english)
    
    // Pre-computed category embeddings (cached)
    private var categoryEmbeddings: [Category: [Double]] = [:]
    private var isInitialized = false
    
    private init() {
        initializeCategoryEmbeddings()
    }
    
    private func initializeCategoryEmbeddings() {
        // Keywords for each category (fallback + seed for embedding)
        let categoryKeywords: [Category: [String]] = [
            .housing: ["rent", "mortgage", "property", "hoa", "home insurance", "property tax"],
            .utilities: ["electric", "electricity", "gas", "water", "utility", "power", "energy", "sewage", "trash"],
            .subscriptions: ["netflix", "spotify", "hulu", "disney", "amazon prime", "subscription", "membership", "hbo", "apple music", "youtube premium", "software", "app subscription"],
            .insurance: ["insurance", "life insurance", "car insurance", "health insurance", "dental", "vision", "umbrella", "geico", "state farm", "allstate"],
            .phoneInternet: ["phone", "mobile", "at&t", "verizon", "t-mobile", "sprint", "internet", "broadband", "wifi", "comcast", "xfinity", "spectrum"],
            .transportation: ["gas", "fuel", "uber", "lyft", "parking", "toll", "car wash", "registration", "dmv", "license renewal", "public transit"],
            .health: ["doctor", "medical", "hospital", "pharmacy", "rx", "prescription", "therapy", "gym", "fitness", "healthcare", "cvs", "walgreens"],
            .other: []
        ]
        
        // Compute embeddings for seed keywords and average them per category
        for (category, keywords) in categoryKeywords {
            let embeddings = keywords.compactMap { embedder.embedding(for: $0) }
            if !embeddings.isEmpty {
                // Average all keyword embeddings
                let avg = averageEmbedding(embeddings)
                categoryEmbeddings[category] = avg
            }
        }
        isInitialized = true
    }
    
    /// Suggest a category for a bill based on its name/vendor
    func suggestCategory(for billName: String) -> Category {
        // First check user corrections stored in UserDefaults
        let corrections = UserDefaults.standard.dictionary(forKey: "categoryCorrections") as? [String: String] ?? [:]
        let normalizedName = billName.lowercased()

        for (pattern, categoryRaw) in corrections {
            if normalizedName.localizedCaseInsensitiveContains(pattern) {
                if let category = Category(rawValue: categoryRaw) {
                    return category
                }
            }
        }

        // Fall back to ML model
        guard let queryEmbedding = embedder.embedding(for: billName) else {
            return .other
        }

        var bestCategory: Category = .other
        var bestSimilarity: Double = 0.0

        for (category, categoryEmbedding) in categoryEmbeddings {
            let similarity = cosineSimilarity(queryEmbedding, categoryEmbedding)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestCategory = category
            }
        }

        // Threshold: if similarity is too low, default to .other
        return bestSimilarity > 0.3 ? bestCategory : .other
    }

    /// Learn from user corrections to improve future suggestions.
    /// Stores bill name patterns → category mappings in UserDefaults.
    func learnFromCorrection(billName: String, correctedCategory: Category) {
        var corrections = UserDefaults.standard.dictionary(forKey: "categoryCorrections") as? [String: String] ?? [:]
        // Store a lowercase pattern for case-insensitive matching
        corrections[billName.lowercased()] = correctedCategory.rawValue
        UserDefaults.standard.set(corrections, forKey: "categoryCorrections")
    }
    
    // MARK: - Embedding Helpers
    
    private func averageEmbedding(_ embeddings: [[Double]]) -> [Double] {
        guard !embeddings.isEmpty else { return [] }
        let dimension = embeddings[0].count
        var result = [Double](repeating: 0, count: dimension)
        for emb in embeddings {
            for i in 0..<min(dimension, emb.count) {
                result[i] += emb[i]
            }
        }
        let count = Double(embeddings.count)
        return result.map { $0 / count }
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Double = 0
        var normA: Double = 0
        var normB: Double = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }
}

// MARK: - NLEmbedder

/// Wrapper for NaturalLanguage embedding functionality
final class NLEmbedder {
    let language: NLLanguage
    
    init(language: NLLanguage = .english) {
        self.language = language
    }
    
    /// Get embedding vector for a given text
    func embedding(for text: String) -> [Double]? {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        
        // Use sentence embedding approximation via tokenization
        // NaturalLanguage doesn't expose raw embedding vectors in the same way as CoreML
        // We use a bag-of-words style approach with word embeddings
        var embedding = [Double](repeating: 0, count: 128)
        var count = 0
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range]).lowercased()
            let wordEmb = wordEmbedding(word)
            if !wordEmb.isEmpty {
                for i in 0..<min(128, wordEmb.count) {
                    embedding[i] += wordEmb[i]
                }
                count += 1
            }
            return true
        }
        
        if count > 0 {
            return embedding.map { $0 / Double(count) }
        }
        
        // Fallback: simple character n-gram hash embedding
        return simpleTextEmbedding(text)
    }
    
    /// Simple word embedding simulation using hash-based vectors
    private func wordEmbedding(_ word: String) -> [Double] {
        // Simple deterministic pseudo-embedding based on word hash
        // In production, you would use a pre-trained model like word2vec or BERT
        var embedding = [Double](repeating: 0, count: 128)
        for (i, char) in word.enumerated() {
            let index = abs(char.hashValue + i * 31) % 128
            embedding[index] += Double(char.asciiValue ?? 0) / 255.0
        }
        return embedding
    }
    
    /// Simple text embedding as fallback
    private func simpleTextEmbedding(_ text: String) -> [Double] {
        var embedding = [Double](repeating: 0, count: 128)
        let words = text.lowercased().split(separator: " ").map(String.init)
        for word in words {
            let wordEmb = wordEmbedding(word)
            for i in 0..<128 {
                embedding[i] += wordEmb[i]
            }
        }
        let count = max(1, words.count)
        return embedding.map { $0 / Double(count) }
    }
}
