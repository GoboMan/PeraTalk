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

    func loadFeedback(sessionRemoteId: UUID) async {
        _ = sessionRemoteId
        // TODO: セッションに紐づくフィードバックを取得
    }

    func bookmarkCandidate(_ candidate: VocabularyCandidate) async {
        try? await bookmarkCandidateUseCase.execute(candidate: candidate)
    }
}
