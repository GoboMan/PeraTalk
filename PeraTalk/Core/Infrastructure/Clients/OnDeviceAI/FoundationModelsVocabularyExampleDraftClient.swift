import Foundation
import FoundationModels

@Generable(description: "Example English sentences per usage")
private struct GenerableExampleOnlyDraft {
    @Guide(description: "One group per usage slot in order, matching the requested kinds", .maximumCount(4))
    var usageGroups: [GenerableExampleUsageGroup]
}

@Generable(description: "Examples for one part of speech")
private struct GenerableExampleUsageGroup {
    @Guide(description: "One of: noun, verb, adjective, adverb, preposition, conjunction, pronoun, interjection, phrasal_verb, idiom")
    var kind: String

    @Guide(description: "Natural English example sentences", .count(3))
    var examples: [GenerableExampleSentence]
}

@Generable(description: "Example sentence")
private struct GenerableExampleSentence {
    @Guide(description: "Natural English sentence, plain text only")
    var sentenceTarget: String
}

struct FoundationModelsVocabularyExampleDraftClient: OnDeviceVocabularyExampleDraftClient {
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func respond(systemInstructions: String, userPrompt: String) async throws -> WordExampleDraft {
        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: userPrompt, generating: GenerableExampleOnlyDraft.self)
        let draft = response.content
        return WordExampleDraft(
            groups: draft.usageGroups.map { group in
                WordExampleDraftGroup(
                    kind: group.kind,
                    examples: group.examples.map { WordDraftExample(sentenceTarget: $0.sentenceTarget) }
                )
            }
        )
    }
}
