import Foundation

@MainActor
struct GenerateVocabularyExampleDraftUseCase {
    private let vocabularyService: any VocabularyService

    nonisolated init(vocabularyService: any VocabularyService) {
        self.vocabularyService = vocabularyService
    }

    func execute(headword: String, usageKinds: [VocabularyKind]) async throws -> WordExampleDraft {
        try await vocabularyService.generateExampleOnlyDraft(headword: headword, usageKinds: usageKinds)
    }

    /// 単一の品詞スロット向けに先頭の英文例を 1 件だけ取り出す（行単位の AI 生成用）。取得できなければ `nil`。
    func firstExampleSentence(headword: String, usageKind: VocabularyKind) async throws -> String? {
        let draft = try await execute(headword: headword, usageKinds: [usageKind])
        let sentences = draft.groups.first?.examples.map(\.sentenceTarget) ?? []
        return sentences
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
