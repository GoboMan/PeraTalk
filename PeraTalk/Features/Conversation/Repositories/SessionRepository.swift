import Foundation

@MainActor
protocol SessionRepository {
    func fetchAll() async throws -> [CachedSession]
    func fetchByDate(_ date: Date) async throws -> [CachedSession]
    func fetchById(remoteId: UUID) async throws -> CachedSession?
    func save(_ session: CachedSession) async throws
    func appendUtterance(to session: CachedSession, role: String, text: String, occurredAt: Date) async throws
    func markDeleted(_ session: CachedSession) async throws
}
