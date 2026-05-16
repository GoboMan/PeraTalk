import Foundation

enum SyncCategory: String, CaseIterable {
    case personas
    case themes
    case profiles
    case subscriptions
    case sessions
    case sessionFeedbacks = "session_feedbacks"
    case vocabulary
    case tags
    case sessionMemorySummaries = "summaries"
}
