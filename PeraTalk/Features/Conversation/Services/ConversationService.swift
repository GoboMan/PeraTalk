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

    func appendUtterance(to session: CachedSession, role: String, text: String) async throws

    func endSession(session: CachedSession, utterances: [ChatMessage]) async throws -> FeedbackResult
    func generateCandidates(utterances: [ChatMessage]) async throws -> [VocabularyCandidate]

    func speak(text: String, locale: String, gender: String?) async
    func enqueueAssistantSpeechFragment(_ text: String, locale: String, gender: String?) async
    func flushAssistantSpeech(locale: String, gender: String?) async
    func cancelAssistantSpeechQueue()

    // MARK: - 音声入力（録音 → 転写）

    /// マイク権限の確認・要求。許可されたら true。
    func ensureMicrophonePermission() async -> Bool

    /// 音声認識モデル等のウォームアップ（任意呼び出し）。
    func warmUpSpeechRecognizer() async

    /// TTS エンジン（オンデバイスモデル等）の先読み。失敗しても発話は別途試行される。
    func warmUpTextToSpeech() async

    /// 1 ターン分のユーザー発話の録音を開始する。
    func startUserRecording() async throws

    /// 録音のみ中止する（転写は行わない）。
    func cancelUserRecording() async

    /// 録音を停止し、Whisper で英語テキストに転写して返す。
    func stopUserRecordingAndTranscribe() async throws -> String
}
