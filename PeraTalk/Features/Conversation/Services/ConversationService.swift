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
    func endSession(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult
    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate]
    func speak(text: String, locale: String, gender: String?) async
}

// MARK: - Stub

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

    func endSession(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult {
        FeedbackResult(
            grammarStrength: nil,
            grammarWeakness: nil,
            vocabularyStrength: nil,
            vocabularyWeakness: nil,
            rawText: ""
        )
    }

    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        []
    }

    func speak(text: String, locale: String, gender: String?) async {}
}

// MARK: - Live

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
}
