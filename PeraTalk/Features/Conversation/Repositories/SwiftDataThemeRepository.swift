import Foundation
import SwiftData

@MainActor
struct SwiftDataThemeRepository: ThemeRepository {
    let context: ModelContext

    func fetchActive() async throws -> [CachedTheme] {
        try context.fetch(
            FetchDescriptor<CachedTheme>(
                predicate: #Predicate<CachedTheme> { theme in !theme.tombstone && theme.isActive }
            )
        )
    }

    func save(_ theme: CachedTheme) async throws {
        context.insert(theme)
        try context.save()
    }

    func markDeleted(_ theme: CachedTheme) async throws {
        theme.tombstone = true
        try context.save()
    }
}
