import Foundation

@MainActor
protocol VocabularyRepository {
    func fetchAll() async throws -> [CachedVocabulary]
    func fetchById(remoteId: UUID) async throws -> CachedVocabulary?
    func fetchByTagId(tagId: UUID) async throws -> CachedVocabulary?
    func search(query: String) async throws -> [CachedVocabulary]
    func save(_ vocabulary: CachedVocabulary) async throws
    func markDeleted(_ vocabulary: CachedVocabulary) async throws
    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws
}

struct StubVocabularyRepository: VocabularyRepository {
    nonisolated init() {}
    func fetchAll() async throws -> [CachedVocabulary] { [] }
    func fetchById(remoteId: UUID) async throws -> CachedVocabulary? { nil }
    func fetchByTagId(tagId: UUID) async throws -> CachedVocabulary? { nil }
    func search(query: String) async throws -> [CachedVocabulary] { [] }
    func save(_ vocabulary: CachedVocabulary) async throws {}
    func markDeleted(_ vocabulary: CachedVocabulary) async throws {}
    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws {}
}
