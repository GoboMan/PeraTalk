import Foundation

@MainActor
protocol LearningLogRepository {
    func fetchSessionsInMonth(_ date: Date) async throws -> [CachedSession]
    func fetchSessionsByDate(_ date: Date) async throws -> [CachedSession]
    func fetchSession(remoteId: UUID) async throws -> CachedSession?
}
