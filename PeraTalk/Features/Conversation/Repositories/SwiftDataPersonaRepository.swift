import Foundation
import SwiftData

@MainActor
struct SwiftDataPersonaRepository: PersonaRepository {
    let context: ModelContext

    func fetchActive() async throws -> [CachedPersona] {
        try context.fetch(
            FetchDescriptor<CachedPersona>(
                predicate: #Predicate<CachedPersona> { persona in persona.isActive }
            )
        )
    }

    func fetchBySlug(_ slug: String) async throws -> CachedPersona? {
        var d = FetchDescriptor<CachedPersona>(predicate: #Predicate<CachedPersona> { persona in persona.slug == slug })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func loadSeedIfNeeded() async throws {}
}
