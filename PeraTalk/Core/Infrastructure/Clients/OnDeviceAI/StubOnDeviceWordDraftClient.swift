import Foundation

struct StubOnDeviceWordDraftClient: OnDeviceWordDraftClient {
    var isAvailable: Bool { false }

    func respond(systemInstructions: String, userPrompt: String) async throws -> WordDraft {
        WordDraft(usages: [], suggestedTags: [])
    }
}
