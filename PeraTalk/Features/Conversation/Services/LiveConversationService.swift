import Foundation

@MainActor
final class LiveConversationService: ConversationService {
    private let personaRepository: any PersonaRepository
    private let themeRepository: any ThemeRepository
    private let sessionRepository: any SessionRepository
    private let llmClient: any LLMClient
    private let ttsClient: any TTSClient
    private let speechRecognizerClient: any SpeechRecognizerClient
    private let audioRecorderClient: any AudioRecorderClient

    init(
        personaRepository: any PersonaRepository,
        themeRepository: any ThemeRepository,
        sessionRepository: any SessionRepository,
        llmClient: any LLMClient,
        ttsClient: any TTSClient,
        speechRecognizerClient: any SpeechRecognizerClient,
        audioRecorderClient: any AudioRecorderClient
    ) {
        self.personaRepository = personaRepository
        self.themeRepository = themeRepository
        self.sessionRepository = sessionRepository
        self.llmClient = llmClient
        self.ttsClient = ttsClient
        self.speechRecognizerClient = speechRecognizerClient
        self.audioRecorderClient = audioRecorderClient
    }

    func fetchActivePersonas() async throws -> [CachedPersona] {
        try await personaRepository.fetchActive()
    }

    func fetchActiveThemes() async throws -> [CachedTheme] {
        try await themeRepository.fetchActive()
    }

    func startSession(mode: SessionMode, personaId: UUID?, themeId: UUID?) async throws -> CachedSession {
        CachedSession(mode: mode.rawValue, personaId: personaId, themeId: themeId)
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

    func appendUtterance(to session: CachedSession, role: String, text: String) async throws {}

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

    // MARK: - 音声入力

    func ensureMicrophonePermission() async -> Bool {
        await audioRecorderClient.requestPermission()
    }

    func warmUpSpeechRecognizer() async {
        try? await speechRecognizerClient.warmUp()
    }

    func warmUpTextToSpeech() async {
        try? await ttsClient.warmUp()
    }

    func startUserRecording() async throws {
        try await audioRecorderClient.startRecording()
    }

    func cancelUserRecording() async {
        await audioRecorderClient.cancelRecording()
    }

    func stopUserRecordingAndTranscribe() async throws -> String {
        let url = try await audioRecorderClient.stopRecording()
        defer { try? FileManager.default.removeItem(at: url) }
        return try await speechRecognizerClient.transcribe(audioFileURL: url)
    }
}
