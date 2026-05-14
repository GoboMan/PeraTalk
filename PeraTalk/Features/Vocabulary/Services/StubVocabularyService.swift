import Foundation

struct StubVocabularyService: VocabularyService {
    nonisolated init() {}
    func save(_ vocabulary: CachedVocabulary) async throws {}
    func markDeleted(_ vocabulary: CachedVocabulary) async throws {}
    func fetchByRemoteId(_ remoteId: UUID) async throws -> CachedVocabulary? { nil }
    func upsertAddForm(_ payload: VocabularyAddFormPayload) async throws {}
    func bookmarkCandidate(_ candidate: VocabularyCandidate) async throws {}

    func generateWordDraft(
        headword: String,
        nativeLanguage: AuxiliaryLanguage,
        availableTags: [String]
    ) async throws -> WordDraft {
        WordDraft(usages: [], suggestedTags: [])
    }

    func generateExampleOnlyDraft(headword: String, linkedLemmaStableId: UUID?, slots: [VocabularyExampleDraftUsageSlot]) async throws -> WordExampleDraft {
        WordExampleDraft(groups: [])
    }

    func lookupIPA(for headword: String) -> String? { nil }
}
