import Foundation

/// 会話開始・セッション中の LLM／TTS・セッション永続化を束ねるアプリケーションサービス。
/// UseCase は本プロトコル経由でのみこれらの I/O にアクセスする。
@MainActor
protocol ConversationService {
    func fetchActivePersonas() async throws -> [CachedPersona]
    func fetchActiveThemes() async throws -> [CachedTheme]
    func startSession(mode: SessionMode, personaId: UUID?, themeId: UUID?) async throws -> CachedSession
    func sendChat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String

    /// BFF 経由のストリーム。テキストは追記デルタ。
    func streamAssistantChat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error>

    func appendUtterance(to session: CachedSession, role: String, text: String) async throws

    func endSession(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult
    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate]

    func speak(text: String, locale: String, gender: String?) async
    func enqueueAssistantSpeechFragment(_ text: String, locale: String, gender: String?) async
    func flushAssistantSpeech(locale: String, gender: String?) async
    func cancelAssistantSpeechQueue()
}
