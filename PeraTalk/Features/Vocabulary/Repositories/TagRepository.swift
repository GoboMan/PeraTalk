import Foundation

@MainActor
protocol TagRepository {
    func fetchAll() async throws -> [CachedTag]
    func save(_ tag: CachedTag) async throws
    func markDeleted(_ tag: CachedTag) async throws
}

struct StubTagRepository: TagRepository {
    nonisolated init() {}
    func fetchAll() async throws -> [CachedTag] { [] }
    func save(_ tag: CachedTag) async throws {}
    func markDeleted(_ tag: CachedTag) async throws {}
}
