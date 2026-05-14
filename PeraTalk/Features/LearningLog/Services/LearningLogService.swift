import Foundation

/// 学習ログに関するセッション読み取りを束ねるアプリケーションサービス。
@MainActor
protocol LearningLogService {
    func fetchSessionsInMonth(_ month: Date) async throws -> [CachedSession]
    func fetchSessionsByDate(_ date: Date) async throws -> [CachedSession]
    func fetchSession(remoteId: UUID) async throws -> CachedSession?
}
