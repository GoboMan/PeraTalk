import Foundation

struct SpeakConversationTextUseCase {
    let conversationService: any ConversationService

    func execute(text: String, locale: String, gender: String?) async {
        await conversationService.speak(text: text, locale: locale, gender: gender)
    }
}
