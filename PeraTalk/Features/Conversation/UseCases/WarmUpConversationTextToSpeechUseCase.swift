import Foundation

struct WarmUpConversationTextToSpeechUseCase {
    let conversationService: any ConversationService

    func execute() async {
        await conversationService.warmUpTextToSpeech()
    }
}
