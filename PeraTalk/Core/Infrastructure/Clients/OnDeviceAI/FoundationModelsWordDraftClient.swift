import Foundation
import FoundationModels

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
