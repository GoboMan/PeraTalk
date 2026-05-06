import Foundation

@MainActor
protocol MemorySummaryRepository {
    func fetchBySession(sessionRemoteId: UUID) async throws -> CachedSessionMemorySummary?
    func fetchByPersona(personaId: UUID) async throws -> [CachedSessionMemorySummary]
}

struct StubMemorySummaryRepository: MemorySummaryRepository {
    nonisolated init() {}
    func fetchBySession(sessionRemoteId: UUID) async throws -> CachedSessionMemorySummary? { nil }
    func fetchByPersona(personaId: UUID) async throws -> [CachedSessionMemorySummary] { [] }
}
