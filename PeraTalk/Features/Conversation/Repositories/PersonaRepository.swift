import Foundation

@MainActor
protocol PersonaRepository {
    func fetchActive() async throws -> [CachedPersona]
    func fetchBySlug(_ slug: String) async throws -> CachedPersona?
    func loadSeedIfNeeded() async throws
}
