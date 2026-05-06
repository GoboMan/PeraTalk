import Foundation

struct BookmarkCandidateUseCase {
    let vocabularyService: any VocabularyService

    func execute(candidate: VocabularyCandidate) async throws {
        try await vocabularyService.bookmarkCandidate(candidate)
    }
}
