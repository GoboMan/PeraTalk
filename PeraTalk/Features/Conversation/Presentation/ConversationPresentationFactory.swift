import Foundation
import SwiftData
import Supabase

@MainActor
enum ConversationPresentationFactory {
    static func makeConversationService(
        modelContext: ModelContext,
        supabase: SupabaseClient?
    ) -> ConversationService {
        let personaRepo = SwiftDataPersonaRepository(context: modelContext)
        let themeRepo = SwiftDataThemeRepository(context: modelContext)
        let sessionRepo = SwiftDataSessionRepository(context: modelContext)

        let llm: any LLMClient = {
            if let supabase {
                return VertexChatEdgeFunctionLLMClient(functions: supabase.functions)
            }
            if FoundationModelsLLMClient.isAvailable {
                return FoundationModelsLLMClient()
            }
            return StubLLMClient()
        }()

        let tts: any TTSClient = TTSKitTTSClient()
        let recognizer: any SpeechRecognizerClient = WhisperKitSpeechRecognizerClient()
        let recorder: any AudioRecorderClient = AVAudioRecorderAudioRecorderClient()

        return LiveConversationService(
            personaRepository: personaRepo,
            themeRepository: themeRepo,
            sessionRepository: sessionRepo,
            llmClient: llm,
            ttsClient: tts,
            speechRecognizerClient: recognizer,
            audioRecorderClient: recorder
        )
    }

    /// 一覧・開始画面用。
    static func makeStartScreenModel(
        modelContext: ModelContext,
        supabase: SupabaseClient?
    ) -> ConversationStartScreenModel {
        let service = makeConversationService(
            modelContext: modelContext,
            supabase: supabase
        )
        return ConversationStartScreenModel(conversationService: service)
    }

    static func makeSessionScreenModel(
        modelContext: ModelContext,
        supabase: SupabaseClient?,
        sessionRemoteId: UUID
    ) -> ConversationSessionScreenModel {
        let service = makeConversationService(
            modelContext: modelContext,
            supabase: supabase
        )
        return ConversationSessionScreenModel(
            activeSessionRemoteId: sessionRemoteId,
            startUserRecordingUseCase: StartUserRecordingUseCase(conversationService: service),
            stopUserRecordingAndTranscribeUseCase: StopUserRecordingAndTranscribeUseCase(conversationService: service),
            sendMessageUseCase: SendMessageUseCase(conversationService: service),
            speakAssistantTextUseCase: SpeakConversationTextUseCase(conversationService: service),
            ensureMicrophonePermissionUseCase: EnsureMicrophonePermissionUseCase(conversationService: service),
            warmUpSpeechRecognizerUseCase: WarmUpSpeechRecognizerUseCase(conversationService: service),
            warmUpConversationTextToSpeechUseCase: WarmUpConversationTextToSpeechUseCase(conversationService: service),
            cancelUserRecordingUseCase: CancelUserRecordingUseCase(conversationService: service)
        )
    }
}
