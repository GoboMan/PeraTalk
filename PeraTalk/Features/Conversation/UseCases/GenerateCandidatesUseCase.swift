import Foundation

struct GenerateCandidatesUseCase {
    let conversationService: any ConversationService

    func execute(utterances: [ChatMessage]) async throws -> [VocabularyCandidate] {
        []
    }
}
