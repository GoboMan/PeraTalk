import Foundation

struct StubConversationService: ConversationService {
    nonisolated init() {}

    func fetchActivePersonas() async throws -> [CachedPersona] { [] }
    func fetchActiveThemes() async throws -> [CachedTheme] { [] }

    func startSession(mode: SessionMode, personaId: UUID?, themeId: UUID?) async throws -> CachedSession {
        CachedSession(mode: mode.rawValue, personaId: personaId, themeId: themeId)
    }

    func sendChat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        ""
    }

    func appendUtterance(to session: CachedSession, role: String, text: String) async throws {
        _ = session
        _ = role
        _ = text
    }

    func endSession(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult {
        _ = session
        _ = utterances
        return FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        _ = utterances
        return [] as [VocabularyCandidate]
    }

    func speak(text: String, locale: String, gender: String?) async {
        _ = text
        _ = locale
        _ = gender
    }

    func enqueueAssistantSpeechFragment(_ text: String, locale: String, gender: String?) async {
        _ = text
        _ = locale
        _ = gender
    }

    func flushAssistantSpeech(locale: String, gender: String?) async {
        _ = locale
        _ = gender
    }

    func cancelAssistantSpeechQueue() {}

    func ensureMicrophonePermission() async -> Bool { false }

    func warmUpSpeechRecognizer() async {}

    func warmUpTextToSpeech() async {}

    func startUserRecording() async throws {}

    func cancelUserRecording() async {}

    func stopUserRecordingAndTranscribe() async throws -> String { "" }
}
