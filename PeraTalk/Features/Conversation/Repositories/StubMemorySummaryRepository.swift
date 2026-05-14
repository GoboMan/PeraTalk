import Foundation

struct StubMemorySummaryRepository: MemorySummaryRepository {
    nonisolated init() {}
    func fetchBySession(sessionRemoteId: UUID) async throws -> CachedSessionMemorySummary? { nil }
    func fetchByPersona(personaId: UUID) async throws -> [CachedSessionMemorySummary] { [] }
}
