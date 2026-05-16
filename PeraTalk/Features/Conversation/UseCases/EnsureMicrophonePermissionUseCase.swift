import Foundation

struct EnsureMicrophonePermissionUseCase {
    let conversationService: any ConversationService

    func execute() async -> Bool {
        await conversationService.ensureMicrophonePermission()
    }
}
