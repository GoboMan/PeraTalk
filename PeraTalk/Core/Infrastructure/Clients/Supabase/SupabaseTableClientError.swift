import Foundation

enum SupabaseTableClientError: Error {
    /// Supabase Auth にセッションが無い（匿名／未ログイン）とき `updateLastSeenAt` などは実行しない。
    case noAuthenticatedSession
}
