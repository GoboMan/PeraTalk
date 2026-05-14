import Foundation

struct StubPersonaRepository: PersonaRepository {
    nonisolated init() {}
    func fetchActive() async throws -> [CachedPersona] { [] }
    func fetchBySlug(_ slug: String) async throws -> CachedPersona? { nil }
    func loadSeedIfNeeded() async throws {}
}
