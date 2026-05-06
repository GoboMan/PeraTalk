import Foundation

@MainActor
struct GenerateVocabularyAddFormDraftUseCase {
    private let vocabularyService: any VocabularyService

    nonisolated init(vocabularyService: any VocabularyService) {
        self.vocabularyService = vocabularyService
    }

    func execute(
        headword: String,
        nativeLanguage: AuxiliaryLanguage,
        tags: [TagPickerItem]
    ) async throws -> VocabularyAddFormPayload {
        let word = headword.trimmingCharacters(in: .whitespaces)
        let draft = try await vocabularyService.generateWordDraft(
            headword: word,
            nativeLanguage: nativeLanguage,
            availableTags: tags.map(\.name)
        )
        let ipa = vocabularyService.lookupIPA(for: word) ?? ""

        let usageLines = draft.usages.map { usage in
            let examples = usage.examples.map {
                VocabularyAddFormExampleLine(sentence: $0.sentenceTarget)
            }
            return VocabularyAddFormUsageLine(
                kind: VocabularyKind(rawValue: usage.kind) ?? .noun,
                ipa: ipa,
                definitionAux: usage.definitionAux ?? "",
                definitionTarget: usage.definitionTarget,
                examples: examples
            )
        }

        var selectedTagIds = Set<UUID>()
        for suggestedName in draft.suggestedTags {
            if let tag = tags.first(where: { $0.name.lowercased() == suggestedName.lowercased() }) {
                selectedTagIds.insert(tag.remoteId)
            }
        }

        return VocabularyAddFormPayload(
            headword: word,
            usages: usageLines,
            selectedTagRemoteIds: selectedTagIds,
            editingVocabularyRemoteId: nil,
            linkedLemmaStableId: nil,
            linkedAdjunctLemmaStableId: nil
        )
    }
}
