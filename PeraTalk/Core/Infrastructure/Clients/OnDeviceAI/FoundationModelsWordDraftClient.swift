import Foundation
import FoundationModels

@Generable(description: "English vocabulary word analysis")
struct GenerableWordDraft {
    @Guide(description: "Usages by part of speech", .maximumCount(4))
    var usages: [GenerableUsage]

    @Guide(description: "Tag names for categorization", .maximumCount(3))
    var suggestedTags: [String]
}

@Generable(description: "A usage for one part of speech")
struct GenerableUsage {
    @Guide(description: "One of: noun, verb, adjective, adverb, preposition, conjunction, pronoun, interjection, phrasal_verb, idiom")
    var kind: String

    @Guide(description: "Short English definition, plain text only, no special characters")
    var definitionTarget: String

    @Guide(description: "Short native language definition, plain text only")
    var definitionAux: String

    @Guide(description: "Example sentences", .count(2))
    var examples: [GenerableExample]
}

@Generable(description: "Example sentence")
struct GenerableExample {
    @Guide(
        description: "Natural English sentence: plain prose only — never asterisks for bold (**), never Markdown.",
    )
    var sentenceTarget: String
}

struct FoundationModelsWordDraftClient: OnDeviceWordDraftClient {
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func respond(systemInstructions: String, userPrompt: String) async throws -> WordDraft {
        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: userPrompt, generating: GenerableWordDraft.self)
        let draft = response.content

        return WordDraft(
            usages: draft.usages.map { usage in
                WordDraftUsage(
                    kind: usage.kind,
                    definitionTarget: usage.definitionTarget,
                    definitionAux: usage.definitionAux,
                    ipa: nil,
                    examples: usage.examples.map { example in
                        WordDraftExample(sentenceTarget: example.sentenceTarget)
                    }
                )
            },
            suggestedTags: draft.suggestedTags
        )
    }
}
