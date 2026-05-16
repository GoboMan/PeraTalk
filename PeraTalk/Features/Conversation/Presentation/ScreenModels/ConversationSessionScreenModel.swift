import Foundation
import Observation
import SwiftData

/// 音声会話セッションの ScreenModel。
/// ChatGPT 風に「テキスト入力 + マイクボタン」の両方の入口を提供する。
@MainActor
@Observable
final class ConversationSessionScreenModel {
    let activeSessionRemoteId: UUID
    private(set) var transcript: [VoiceChatTurn] = []
    private(set) var phase: VoiceTurnPhase = .idle

    /// テキスト入力欄。録音停止後の転写結果もここに詰める。
    var inputText: String = ""

    /// LLM に与える Persona／Theme（呼び出し元から差し込む。今回は空でも会話は成立）。
    var personaPrompt: String?
    var themeDescription: String?

    /// AVSpeech に使うロケール（英会話前提）。
    var spokenLocale: String = "en-US"

    private let startUserRecordingUseCase: StartUserRecordingUseCase
    private let stopUserRecordingAndTranscribeUseCase: StopUserRecordingAndTranscribeUseCase
    private let sendMessageUseCase: SendMessageUseCase
    private let speakAssistantTextUseCase: SpeakConversationTextUseCase
    private let ensureMicrophonePermissionUseCase: EnsureMicrophonePermissionUseCase
    private let warmUpSpeechRecognizerUseCase: WarmUpSpeechRecognizerUseCase
    private let warmUpConversationTextToSpeechUseCase: WarmUpConversationTextToSpeechUseCase
    private let cancelUserRecordingUseCase: CancelUserRecordingUseCase

    init(
        activeSessionRemoteId: UUID,
        startUserRecordingUseCase: StartUserRecordingUseCase,
        stopUserRecordingAndTranscribeUseCase: StopUserRecordingAndTranscribeUseCase,
        sendMessageUseCase: SendMessageUseCase,
        speakAssistantTextUseCase: SpeakConversationTextUseCase,
        ensureMicrophonePermissionUseCase: EnsureMicrophonePermissionUseCase,
        warmUpSpeechRecognizerUseCase: WarmUpSpeechRecognizerUseCase,
        warmUpConversationTextToSpeechUseCase: WarmUpConversationTextToSpeechUseCase,
        cancelUserRecordingUseCase: CancelUserRecordingUseCase
    ) {
        self.activeSessionRemoteId = activeSessionRemoteId
        self.startUserRecordingUseCase = startUserRecordingUseCase
        self.stopUserRecordingAndTranscribeUseCase = stopUserRecordingAndTranscribeUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.speakAssistantTextUseCase = speakAssistantTextUseCase
        self.ensureMicrophonePermissionUseCase = ensureMicrophonePermissionUseCase
        self.warmUpSpeechRecognizerUseCase = warmUpSpeechRecognizerUseCase
        self.warmUpConversationTextToSpeechUseCase = warmUpConversationTextToSpeechUseCase
        self.cancelUserRecordingUseCase = cancelUserRecordingUseCase
    }

    /// 画面表示時に呼ぶ。マイク権限取得と Whisper / TTS のウォームアップを行う。
    func bootstrap() async {
        _ = await ensureMicrophonePermissionUseCase.execute()
        phase = .loadingModel
        async let speech: Void = warmUpSpeechRecognizerUseCase.execute()
        async let tts: Void = warmUpConversationTextToSpeechUseCase.execute()
        _ = await (speech, tts)
        if phase == .loadingModel {
            phase = .idle
        }
    }

    /// 録音ボタンが押下されたときの単一エントリ。フェーズに応じて開始/停止を切り替える。
    func toggleRecording() async {
        switch phase {
        case .idle, .failed, .loadingModel:
            await beginRecording()
        case .recording:
            await endRecordingAndFillInput()
        case .transcribing, .awaitingAssistant, .speakingAssistant:
            break
        }
    }

    /// テキスト送信（Send ボタン）。
    func sendTextMessage() async {
        let cleaned = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        inputText = ""
        appendTurn(role: "user", text: cleaned)
        await callAssistantAndSpeak()
    }

    /// 録音中であれば破棄して idle に戻す（バックグラウンド遷移等のフェイルセーフ）。
    func discardOngoingRecording() async {
        guard phase == .recording else { return }
        await cancelUserRecordingUseCase.execute()
        phase = .idle
    }

    private func beginRecording() async {
        let allowed = await ensureMicrophonePermissionUseCase.execute()
        guard allowed else {
            phase = .failed("マイクの利用が許可されていません。設定アプリから許可してください。")
            return
        }
        do {
            try await startUserRecordingUseCase.execute()
            phase = .recording
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func endRecordingAndFillInput() async {
        phase = .transcribing
        do {
            let transcribed = try await stopUserRecordingAndTranscribeUseCase.execute()
            let cleaned = transcribed.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                phase = .failed("音声を認識できませんでした。もう一度お試しください。")
            } else {
                inputText = cleaned
                phase = .idle
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func callAssistantAndSpeak() async {
        phase = .awaitingAssistant
        let messages = transcript.map { ChatMessage(role: $0.role, text: $0.text) }
        async let ttsPrimed: Void = warmUpConversationTextToSpeechUseCase.execute()
        let assistantText: String
        do {
            assistantText = try await sendMessageUseCase.execute(
                messages: messages,
                personaPrompt: personaPrompt,
                themeDescription: themeDescription
            )
        } catch {
            await ttsPrimed
            phase = .failed(error.localizedDescription)
            return
        }

        await ttsPrimed

        let trimmedAssistant = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAssistant.isEmpty else {
            phase = .failed("AI から応答がありませんでした。")
            return
        }
        appendTurn(role: "assistant", text: trimmedAssistant)

        phase = .speakingAssistant
        await speakAssistantTextUseCase.execute(
            text: trimmedAssistant,
            locale: spokenLocale,
            gender: nil
        )
        phase = .idle
    }

    private func appendTurn(role: String, text: String) {
        transcript.append(VoiceChatTurn(id: UUID(), role: role, text: text))
    }
}
