import Foundation

@MainActor
protocol ThemeRepository {
    func fetchActive() async throws -> [CachedTheme]
    func save(_ theme: CachedTheme) async throws
    func markDeleted(_ theme: CachedTheme) async throws
}

struct StubThemeRepository: ThemeRepository {
    nonisolated init() {}
    func fetchActive() async throws -> [CachedTheme] { [] }
    func save(_ theme: CachedTheme) async throws {}
    func markDeleted(_ theme: CachedTheme) async throws {}
}
