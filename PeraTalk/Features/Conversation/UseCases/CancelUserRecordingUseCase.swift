import Foundation

struct CancelUserRecordingUseCase {
    let conversationService: any ConversationService

    func execute() async {
        await conversationService.cancelUserRecording()
    }
}
