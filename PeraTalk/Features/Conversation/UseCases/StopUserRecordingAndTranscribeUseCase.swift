import Foundation

struct StopUserRecordingAndTranscribeUseCase {
    let conversationService: any ConversationService

    func execute() async throws -> String {
        try await conversationService.stopUserRecordingAndTranscribe()
    }
}
