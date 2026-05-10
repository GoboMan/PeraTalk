import Foundation

@MainActor
struct GenerateVocabularyExampleDraftUseCase {
    private let vocabularyService: any VocabularyService

    nonisolated init(vocabularyService: any VocabularyService) {
        self.vocabularyService = vocabularyService
    }

    func execute(headword: String, linkedLemmaStableId: UUID?, slots: [VocabularyExampleDraftUsageSlot]) async throws -> WordExampleDraft {
        try await vocabularyService.generateExampleOnlyDraft(headword: headword, linkedLemmaStableId: linkedLemmaStableId, slots: slots)
    }

    /// 単一の品詞スロット向けに先頭の英文例を 1 件だけ取り出す（行単位の AI 生成用）。取得できなければ `nil`。
    func firstExampleSentence(
        headword: String,
        linkedLemmaStableId: UUID?,
        slot: VocabularyExampleDraftUsageSlot
    ) async throws -> String? {
        let draft = try await execute(headword: headword, linkedLemmaStableId: linkedLemmaStableId, slots: [slot])
        let sentences = draft.groups.first?.examples.map(\.sentenceTarget) ?? []
        return sentences
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
