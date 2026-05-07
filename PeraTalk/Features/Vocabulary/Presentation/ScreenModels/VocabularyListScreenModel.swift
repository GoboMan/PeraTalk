import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class VocabularyListScreenModel {
    var searchQuery: String = ""
    var selectedTagId: UUID?
    /// サーバー辞書パック同期後のユーザー向けメッセージ（成功・失敗）。
    var remoteDictionaryPackBanner: String?
    var isSyncingRemoteDictionaryPack = false

    private let deleteVocabularyUseCase: DeleteVocabularyUseCase
    private let applyCatalogRemoteDictionaryPackUseCase: ApplyCatalogRemoteDictionaryPackUseCase?

    init(
        deleteVocabularyUseCase: DeleteVocabularyUseCase = DeleteVocabularyUseCase(vocabularyService: StubVocabularyService()),
        applyCatalogRemoteDictionaryPackUseCase: ApplyCatalogRemoteDictionaryPackUseCase? = nil
    ) {
        self.deleteVocabularyUseCase = deleteVocabularyUseCase
        self.applyCatalogRemoteDictionaryPackUseCase = applyCatalogRemoteDictionaryPackUseCase
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

    /// Supabase カタログ経由でリモート辞書パックを取得して SwiftData に適用する（`en_lemmas` 既定）。
    func syncRemoteDictionaryPackFromCatalog(packKey: String = "en_lemmas", context: ModelContext) async {
        remoteDictionaryPackBanner = nil
        guard let useCase = applyCatalogRemoteDictionaryPackUseCase else {
            remoteDictionaryPackBanner = "Supabase が未設定です。SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY を確認してください。"
            return
        }
        guard !isSyncingRemoteDictionaryPack else { return }
        isSyncingRemoteDictionaryPack = true
        defer { isSyncingRemoteDictionaryPack = false }
        do {
            try await useCase.execute(packKey: packKey, context: context)
            remoteDictionaryPackBanner = "サーバーの辞書パックを適用しました。"
        } catch let error as ApplyCatalogRemoteDictionaryPackError {
            remoteDictionaryPackBanner = error.localizedDescription
        } catch {
            remoteDictionaryPackBanner = error.localizedDescription
        }
    }

    /// SwiftData を使う実行時構成。
    static func live(
        modelContext: ModelContext,
        supabaseTableClient: (any SupabaseTableClient)?
    ) -> VocabularyListScreenModel {
        let repository = SwiftDataVocabularyRepository(context: modelContext)
        let service = LiveVocabularyService(
            vocabularyRepository: repository,
            onDeviceWordDraftClient: FoundationModelsWordDraftClient(),
            onDeviceExampleDraftClient: FoundationModelsVocabularyExampleDraftClient(),
            pronunciationRepository: CMUDictPronunciationRepository(),
            lemmaLookupRepository: SwiftDataLemmaLookupRepository(context: modelContext)
        )

        let catalogApply: ApplyCatalogRemoteDictionaryPackUseCase? = {
            guard let tableClient = supabaseTableClient,
                  let creds = SupabaseBundleCredentials.load(),
                  let projectURL = URL(string: creds.supabaseURL)
            else { return nil }
            let catalog = LiveDictionaryPackCatalogService(supabaseURL: projectURL, tableClient: tableClient)
            return ApplyCatalogRemoteDictionaryPackUseCase(catalogService: catalog)
        }()

        return VocabularyListScreenModel(
            deleteVocabularyUseCase: DeleteVocabularyUseCase(vocabularyService: service),
            applyCatalogRemoteDictionaryPackUseCase: catalogApply
        )
    }
}
