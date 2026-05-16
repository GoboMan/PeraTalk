import Foundation

struct StartUserRecordingUseCase {
    let conversationService: any ConversationService

    func execute() async throws {
        try await conversationService.startUserRecording()
    }
}
