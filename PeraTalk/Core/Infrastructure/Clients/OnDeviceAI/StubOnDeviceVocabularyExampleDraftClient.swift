import Foundation

struct StubOnDeviceVocabularyExampleDraftClient: OnDeviceVocabularyExampleDraftClient {
    var isAvailable: Bool { false }

    func respond(systemInstructions: String, userPrompt: String) async throws -> WordExampleDraft {
        WordExampleDraft(groups: [])
    }
}
