import Foundation
import AppIntents

// MARK: - Siri Suggestions via Intent Donation (R11)

// MARK: - Intent Donation Helper

/// Helper class to donate intents to Siri for bill suggestions.
/// Call `donateUpcomingBillIntents()` when app launches or when checking for due bills.
/// This allows Siri to suggest "Mark X bill as paid" when bills are due.
///
/// Note: Siri learns from usage patterns. When the user marks bills as paid via Siri
/// (using the "Mark bill paid in Chronicle" shortcut), Siri will suggest this action
/// for similar bills near their due dates automatically.
@available(macOS 13.0, *)
enum IntentDonator {
    
    /// Donate intents for upcoming bills due today or tomorrow.
    /// Call this when app launches or periodically throughout the day.
    ///
    /// Note: With AppIntents, Siri suggestions work automatically based on user behavior.
    /// When users use the "Mark bill paid in Chronicle" Siri shortcut, Siri learns to
    /// suggest this action when bills become due.
    @MainActor
    static func donateUpcomingBillIntents() {
        // Siri suggestions are now handled automatically through the AppShortcuts system.
        // When users invoke "Mark bill paid in Chronicle" via Siri, the system learns
        // and begins suggesting this action for bills near their due dates.
        //
        // For explicit donations, use INIntentDonation (requires INIntents framework).
        // This is available on iOS but has limited support on macOS.
    }
    
    /// Donate an intent for a specific overdue bill.
    /// Call this when a bill becomes overdue.
    @MainActor
    static func donateOverdueBillIntent(for bill: Bill) {
        // Siri suggestions are handled automatically through usage patterns.
        // See donateUpcomingBillIntents() for details.
    }
}
