import Foundation
import Observation

@MainActor
@Observable
final class ConversationSessionScreenModel {
    var utterances: [CachedUtterance] = []
    var inputText: String = ""
    var isWaitingForResponse: Bool = false

    private let sendMessageUseCase: SendMessageUseCase
    private let endSessionUseCase: EndSessionUseCase
    private let speakConversationTextUseCase: SpeakConversationTextUseCase

    init(
        sendMessageUseCase: SendMessageUseCase = SendMessageUseCase(conversationService: StubConversationService()),
        endSessionUseCase: EndSessionUseCase = EndSessionUseCase(conversationService: StubConversationService()),
        speakConversationTextUseCase: SpeakConversationTextUseCase = SpeakConversationTextUseCase(conversationService: StubConversationService())
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.endSessionUseCase = endSessionUseCase
        self.speakConversationTextUseCase = speakConversationTextUseCase
    }

    func sendMessage() async {
        guard !inputText.isEmpty else { return }
        // TODO: ユーザー発話を CachedUtterance に追加 → sendMessageUseCase → AI 応答追加 → speakConversationTextUseCase
        _ = sendMessageUseCase
        _ = speakConversationTextUseCase
    }

    func endSession() async {
        // TODO: endSessionUseCase と候補生成
        _ = endSessionUseCase
    }
}
