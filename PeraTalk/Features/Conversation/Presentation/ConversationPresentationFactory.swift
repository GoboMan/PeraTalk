import Foundation
import SwiftData
import Supabase

@MainActor
enum ConversationPresentationFactory {
    static func makeConversationService(
        modelContext: ModelContext,
        supabase: SupabaseClient?,
        useEdgeAuthenticatedStream: Bool
    ) -> ConversationService {
        let personaRepo = SwiftDataPersonaRepository(context: modelContext)
        let themeRepo = SwiftDataThemeRepository(context: modelContext)
        let sessionRepo = SwiftDataSessionRepository(context: modelContext)

        let llm: any LLMClient
        let tts: any TTSClient

        // TODO: Edge Function 経由は一旦無効化。オンデバイスのみで動作確認する。
        if FoundationModelsLLMClient.isAvailable {
            llm = FoundationModelsLLMClient()
            tts = LiveQueuedAVSpeechTTSClient()
        } else {
            llm = StubLLMClient()
            tts = StubTTSClient()
        }

        return LiveConversationService(
            personaRepository: personaRepo,
            themeRepository: themeRepo,
            sessionRepository: sessionRepo,
            llmClient: llm,
            ttsClient: tts
        )
    }

    /// 一覧・開始画面用。
    static func makeStartScreenModel(
        modelContext: ModelContext,
        supabase: SupabaseClient?,
        useEdgeAuthenticatedStream: Bool
    ) -> ConversationStartScreenModel {
        let service = makeConversationService(
            modelContext: modelContext,
            supabase: supabase,
            useEdgeAuthenticatedStream: useEdgeAuthenticatedStream
        )
        return ConversationStartScreenModel(conversationService: service)
    }

    static func makeSessionScreenModel(
        modelContext: ModelContext,
        supabase: SupabaseClient?,
        useEdgeAuthenticatedStream: Bool,
        sessionRemoteId: UUID
    ) -> ConversationSessionScreenModel {
        let service = makeConversationService(
            modelContext: modelContext,
            supabase: supabase,
            useEdgeAuthenticatedStream: useEdgeAuthenticatedStream
        )
        let sessionRepo = SwiftDataSessionRepository(context: modelContext)
        return ConversationSessionScreenModel(
            activeSessionRemoteId: sessionRemoteId,
            conversationService: service,
            streamAssistantUseCase: StreamAssistantConversationUseCase(conversationService: service),
            appendUtteranceUseCase: AppendConversationUtteranceUseCase(conversationService: service),
            speakConversationTextUseCase: SpeakConversationTextUseCase(conversationService: service),
            endSessionUseCase: EndSessionUseCase(conversationService: service),
            sessionRepository: sessionRepo
        )
    }
}
