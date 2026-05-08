import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class VocabularyListScreenModel {
    var searchQuery: String = ""
    var selectedTagId: UUID?

    private let deleteVocabularyUseCase: DeleteVocabularyUseCase

    init(deleteVocabularyUseCase: DeleteVocabularyUseCase = DeleteVocabularyUseCase(vocabularyService: StubVocabularyService())) {
        self.deleteVocabularyUseCase = deleteVocabularyUseCase
    }

    func filteredVocabularies(
        _ vocabularies: [CachedVocabulary],
        sortOrder: VocabularyListSortOrder = .recentlyAdded
    ) -> [CachedVocabulary] {
        var result = vocabularies.filter { !$0.tombstone }

        if let tagId = selectedTagId {
            result = result.filter { vocab in
                vocab.vocabularyTagLinks.contains { link in
                    !link.tombstone && link.tag?.remoteId == tagId
                }
            }
        }

        if !searchQuery.isEmpty {
            result = result.filter {
                $0.headword.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        switch sortOrder {
        case .recentlyAdded:
            result.sort { $0.cachedAt > $1.cachedAt }
        case .headwordAZ:
            result.sort { $0.headword.localizedStandardCompare($1.headword) == .orderedAscending }
        }

        return result
    }

    func firstUsage(of vocabulary: CachedVocabulary) -> CachedVocabularyUsage? {
        vocabulary.usages
            .filter { !$0.tombstone }
            .sorted { $0.position < $1.position }
            .first
    }

    func selectTag(_ tagId: UUID?) {
        if selectedTagId == tagId {
            selectedTagId = nil
        } else {
            selectedTagId = tagId
        }
    }

    func selectAll() {
        selectedTagId = nil
    }

    func delete(_ vocabulary: CachedVocabulary) async {
        try? await deleteVocabularyUseCase.execute(vocabulary: vocabulary)
    }

    /// SwiftData を使う実行時構成。
    static func live(modelContext: ModelContext) -> VocabularyListScreenModel {
        let repository = SwiftDataVocabularyRepository(context: modelContext)
        let service = LiveVocabularyService(
            vocabularyRepository: repository,
            onDeviceWordDraftClient: FoundationModelsWordDraftClient(),
            onDeviceExampleDraftClient: FoundationModelsVocabularyExampleDraftClient(),
            pronunciationRepository: CMUDictPronunciationRepository(),
            lemmaLookupRepository: SwiftDataLemmaLookupRepository(context: modelContext)
        )

        return VocabularyListScreenModel(
            deleteVocabularyUseCase: DeleteVocabularyUseCase(vocabularyService: service)
        )
    }
}
