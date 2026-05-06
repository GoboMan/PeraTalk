import Foundation

protocol TTSClient {
    func speak(
        text: String,
        locale: String,
        gender: String?
    ) async

    func stop()

    var isSpeaking: Bool { get }
}
