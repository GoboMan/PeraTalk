import Foundation

struct StubSpeechRecognizerClient: SpeechRecognizerClient {
    nonisolated init() {}

    func warmUp() async throws {}

    func transcribe(audioFileURL: URL) async throws -> String {
        _ = audioFileURL
        return ""
    }
}
