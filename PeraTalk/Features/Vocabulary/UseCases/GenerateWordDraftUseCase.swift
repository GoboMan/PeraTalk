import Foundation

struct GenerateWordDraftUseCase {
    let vocabularyService: any VocabularyService

    func execute(headword: String, nativeLanguage: AuxiliaryLanguage, availableTags: [String] = []) async throws -> WordDraft {
        try await vocabularyService.generateWordDraft(
            headword: headword,
            nativeLanguage: nativeLanguage,
            availableTags: availableTags
        )
    }
}
