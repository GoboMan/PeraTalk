import Foundation

struct LiveConversationService: ConversationService {
    private let personaRepository: any PersonaRepository
    private let themeRepository: any ThemeRepository
    private let sessionRepository: any SessionRepository
    private let llmClient: any LLMClient
    private let ttsClient: any TTSClient

    init(
        personaRepository: any PersonaRepository,
        themeRepository: any ThemeRepository,
        sessionRepository: any SessionRepository,
        llmClient: any LLMClient,
        ttsClient: any TTSClient
    ) {
        self.personaRepository = personaRepository
        self.themeRepository = themeRepository
        self.sessionRepository = sessionRepository
        self.llmClient = llmClient
        self.ttsClient = ttsClient
    }

    func fetchActivePersonas() async throws -> [CachedPersona] {
        try await personaRepository.fetchActive()
    }

    func fetchActiveThemes() async throws -> [CachedTheme] {
        try await themeRepository.fetchActive()
    }

    func startSession(mode: SessionMode, personaId: UUID?, themeId: UUID?) async throws -> CachedSession {
        let session = CachedSession(
            mode: mode.rawValue,
            personaId: personaId,
            themeId: themeId
        )
        try await sessionRepository.save(session)
        return session
    }

    func sendChat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) async throws -> String {
        try await llmClient.chat(
            messages: messages,
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        )
    }

    func streamAssistantChat(
        messages: [ChatMessage],
        personaPrompt: String?,
        themeDescription: String?
    ) -> AsyncThrowingStream<String, Error> {
        llmClient.chatStreaming(
            messages: messages,
            personaPrompt: personaPrompt,
            themeDescription: themeDescription
        )
    }

    func appendUtterance(to session: CachedSession, role: String, text: String) async throws {
        try await sessionRepository.appendUtterance(to: session, role: role, text: text, occurredAt: Date())
    }

    func endSession(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult {
        session.endedAt = Date()
        session.dirty = true
        try await sessionRepository.save(session)
        return try await llmClient.generateFeedback(utterances: utterances, mode: session.mode)
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        try await llmClient.generateCandidates(utterances: utterances)
    }

    func speak(text: String, locale: String, gender: String?) async {
        await ttsClient.speak(text: text, locale: locale, gender: gender)
    }

    func enqueueAssistantSpeechFragment(_ text: String, locale: String, gender: String?) async {
        await ttsClient.enqueueFragment(text, locale: locale, gender: gender)
    }

    func flushAssistantSpeech(locale: String, gender: String?) async {
        await ttsClient.flushPendingSpeech(locale: locale, gender: gender)
    }

    func cancelAssistantSpeechQueue() {
        ttsClient.cancelQueuedSpeech()
    }
}
