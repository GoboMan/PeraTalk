import Foundation

struct StubTTSClient: TTSClient {
    func speak(text: String, locale: String, gender: String?) async {}
    func stop() {}
    var isSpeaking: Bool { false }
}
