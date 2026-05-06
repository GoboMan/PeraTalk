import Foundation

struct LoadVocabularyAddFormForEditingUseCase {
    let vocabularyService: any VocabularyService

    func execute(remoteId: UUID) async throws -> VocabularyAddFormPayload? {
        guard let vocabulary = try await vocabularyService.fetchByRemoteId(remoteId) else { return nil }

        let activeUsages = vocabulary.usages
            .filter { !$0.tombstone }
            .sorted { $0.position < $1.position }

        let presetLemma = vocabulary.lemma

        let usageLines = activeUsages.map { usage in
            let examples = usage.examples
                .filter { !$0.tombstone }
                .sorted { $0.position < $1.position }
                .map {
                    VocabularyAddFormExampleLine(sentence: $0.sentenceTarget)
                }

            let kind = VocabularyKind(rawValue: usage.kind) ?? .noun
            let pack = presetLemma.map { $0.packUsageDefinitions(for: kind) }

            let definitionAux: String = {
                let fromUsage = usage.definitionAux?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !fromUsage.isEmpty { return usage.definitionAux ?? "" }
                return pack?.aux ?? ""
            }()

            let definitionTarget: String = {
                let fromUsage = usage.definitionTarget?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !fromUsage.isEmpty { return usage.definitionTarget ?? "" }
                return pack?.target ?? ""
            }()

            return VocabularyAddFormUsageLine(
                kind: kind,
                ipa: usage.ipa ?? "",
                definitionAux: definitionAux,
                definitionTarget: definitionTarget,
                examples: examples
            )
        }

        let tagIds = Set(
            vocabulary.vocabularyTagLinks
                .filter { !$0.tombstone }
                .compactMap { $0.tag?.remoteId }
        )

        return VocabularyAddFormPayload(
            headword: vocabulary.headword,
            usages: usageLines,
            selectedTagRemoteIds: tagIds,
            editingVocabularyRemoteId: vocabulary.remoteId,
            linkedLemmaStableId: vocabulary.lemma?.stableLemmaId,
            linkedAdjunctLemmaStableId: vocabulary.adjunctLemma?.stableLemmaId
        )
    }
}
