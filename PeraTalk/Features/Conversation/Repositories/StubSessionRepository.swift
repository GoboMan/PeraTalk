import Foundation

struct StubSessionRepository: SessionRepository {
    nonisolated init() {}

    func fetchAll() async throws -> [CachedSession] { [] }
    func fetchByDate(_ date: Date) async throws -> [CachedSession] { [] }
    func fetchById(remoteId: UUID) async throws -> CachedSession? { nil }
    func save(_ session: CachedSession) async throws {}

    func appendUtterance(to session: CachedSession, role: String, text: String, occurredAt: Date) async throws {}

    func markDeleted(_ session: CachedSession) async throws {}
}
