import Foundation

struct DeleteVocabularyUseCase {
    let vocabularyService: any VocabularyService

    func execute(vocabulary: CachedVocabulary) async throws {
        try await vocabularyService.markDeleted(vocabulary)
    }
}
