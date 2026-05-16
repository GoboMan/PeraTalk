import Foundation

struct WarmUpSpeechRecognizerUseCase {
    let conversationService: any ConversationService

    func execute() async {
        await conversationService.warmUpSpeechRecognizer()
    }
}
