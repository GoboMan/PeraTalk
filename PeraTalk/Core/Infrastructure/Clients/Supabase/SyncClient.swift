import Foundation

protocol SyncClient {
    func pushPendingChanges() async throws
    func pullAll() async throws
    func pull(category: SyncCategory) async throws
}

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
