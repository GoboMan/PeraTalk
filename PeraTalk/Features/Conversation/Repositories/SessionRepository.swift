import Foundation

@MainActor
protocol SessionRepository {
    func fetchAll() async throws -> [CachedSession]
    func fetchByDate(_ date: Date) async throws -> [CachedSession]
    func fetchById(remoteId: UUID) async throws -> CachedSession?
    func save(_ session: CachedSession) async throws
    func markDeleted(_ session: CachedSession) async throws
}

struct StubSessionRepository: SessionRepository {
    nonisolated init() {}
    func fetchAll() async throws -> [CachedSession] { [] }
    func fetchByDate(_ date: Date) async throws -> [CachedSession] { [] }
    func fetchById(remoteId: UUID) async throws -> CachedSession? { nil }
    func save(_ session: CachedSession) async throws {}
    func markDeleted(_ session: CachedSession) async throws {}
}
