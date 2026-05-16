import Foundation
import Observation

@MainActor
@Observable
final class ConversationResultScreenModel {
    var feedback: CachedSessionFeedback?
    var candidates: [VocabularyCandidate] = []

    private let bookmarkCandidateUseCase: BookmarkCandidateUseCase

    init(bookmarkCandidateUseCase: BookmarkCandidateUseCase = BookmarkCandidateUseCase(vocabularyService: StubVocabularyService())) {
        self.bookmarkCandidateUseCase = bookmarkCandidateUseCase
    }

    func loadFeedback(sessionRemoteId: UUID) async {}

    func bookmarkCandidate(_ candidate: VocabularyCandidate) async {}
}
