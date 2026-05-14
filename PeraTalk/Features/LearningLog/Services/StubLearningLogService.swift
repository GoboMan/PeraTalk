import Foundation

struct StubLearningLogService: LearningLogService {
    nonisolated init() {}
    func fetchSessionsInMonth(_ month: Date) async throws -> [CachedSession] { [] }
    func fetchSessionsByDate(_ date: Date) async throws -> [CachedSession] { [] }
    func fetchSession(remoteId: UUID) async throws -> CachedSession? { nil }
}
