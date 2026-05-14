import Foundation

@MainActor
protocol MemorySummaryRepository {
    func fetchBySession(sessionRemoteId: UUID) async throws -> CachedSessionMemorySummary?
    func fetchByPersona(personaId: UUID) async throws -> [CachedSessionMemorySummary]
}
