import Foundation

struct SpeakConversationTextUseCase {
    let conversationService: any ConversationService

    func execute(text: String, locale: String, gender: String?) async {
        await conversationService.speak(text: text, locale: locale, gender: gender)
    }

    func enqueue(fragment: String, locale: String, gender: String?) async {
        await conversationService.enqueueAssistantSpeechFragment(fragment, locale: locale, gender: gender)
    }

    func flushPending(locale: String, gender: String?) async {
        await conversationService.flushAssistantSpeech(locale: locale, gender: gender)
    }

    func cancelQueue() {
        conversationService.cancelAssistantSpeechQueue()
    }
}
