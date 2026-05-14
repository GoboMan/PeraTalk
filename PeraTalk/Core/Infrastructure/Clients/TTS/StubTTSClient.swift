import Foundation

struct StubTTSClient: TTSClient {
    func speak(text: String, locale: String, gender: String?) async {}
    func enqueueFragment(_ text: String, locale: String, gender: String?) async {}
    func flushPendingSpeech(locale: String, gender: String?) async {}
    func cancelQueuedSpeech() {}
    func stop() {}
    var isSpeaking: Bool { false }
}
