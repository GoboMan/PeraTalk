import SwiftUI
import SwiftData

enum VocabularyRoute: Hashable {
    /// 一覧で表示中だった順序と、開く単語の ID（横スワイプで `sequence` 内を移動）。
    case detail(sequence: [UUID], currentId: UUID)
    case add
    case edit(UUID)
}

struct VocabularyListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model = VocabularyListScreenModel()
    @State private var path = NavigationPath()
    /// 単語詳細の「意味を伏せるモード」。一覧に戻ってもオンなら維持する。
    @State private var vocabularyRecallObfuscationModeEnabled = false
    @State private var showAddTagAlert = false
    @State private var newTagName = ""
    @Query private var profiles: [CachedProfile]
    @Query(filter: #Predicate<CachedVocabulary> { !$0.tombstone },
           sort: \CachedVocabulary.cachedAt, order: .reverse)
    private var vocabularies: [CachedVocabulary]
    @Query(filter: #Predicate<CachedTag> { !$0.tombstone },
           sort: \CachedTag.name)
    private var tags: [CachedTag]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    tagFilterSection
                    vocabularyListSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Vocabulary")
            .task {
                model = VocabularyListScreenModel.live(modelContext: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .searchable(text: $model.searchQuery, prompt: "単語を検索")
            .navigationDestination(for: VocabularyRoute.self) { route in
                switch route {
                case .detail(let sequence, let currentId):
                    VocabularyDetailPagerScreen(
                        sequence: sequence,
                        currentId: currentId,
                        path: $path,
                        recallObfuscationModeEnabled: $vocabularyRecallObfuscationModeEnabled
                    )
                case .add:
                    VocabularyAddScreen()
                case .edit(let id):
                    VocabularyAddScreen(vocabularyId: id)
                }
            }
            .alert("タグを追加", isPresented: $showAddTagAlert) {
                TextField("タグ名", text: $newTagName)
                Button("キャンセル", role: .cancel) {}
                Button("追加") {
                    let name = newTagName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    let tag = CachedTag(name: name)
                    modelContext.insert(tag)
                }
            }
        }
    }

    private var vocabularyPreferences: VocabularyListScreenPreferences {
        profiles.first?.screenDisplayPreferencesOrDefault.vocabularyList ?? VocabularyListScreenPreferences()
    }

    // MARK: - Tag Filter

    private var tagFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChipView(
                    name: "All",
                    isSelected: model.selectedTagId == nil,
                    action: { model.selectAll() }
                )

                ForEach(tags, id: \.remoteId) { tag in
                    TagChipView(
                        name: tag.name,
                        isSelected: model.selectedTagId == tag.remoteId,
                        action: { model.selectTag(tag.remoteId) }
                    )
                }
            }
        }
    }

    // MARK: - Vocabulary List

    private var filteredVocabularies: [CachedVocabulary] {
        model.filteredVocabularies(vocabularies, sortOrder: vocabularyPreferences.sortOrder)
    }

    private var vocabularyListSection: some View {
        let sequence = filteredVocabularies.map(\.remoteId)
        return LazyVStack(spacing: vocabularyPreferences.listDensity == .compact ? 6 : 12) {
            ForEach(filteredVocabularies, id: \.remoteId) { vocabulary in
                let usage = model.firstUsage(of: vocabulary)
                NavigationLink(value: VocabularyRoute.detail(sequence: sequence, currentId: vocabulary.remoteId)) {
                    // 一覧は複数用法がある語で「どの品詞を代表表示するか」が決めにくいため、品詞バッジは出さない（詳細で用法ごとに表示）。
                    VocabularyCardView(
                        headword: vocabulary.headword,
                        showPartOfSpeech: false,
                        kind: nil,
                        japaneseDefinition: vocabularyPreferences.showJapaneseDefinition
                            ? usage.flatMap { vocabulary.resolvedDefinitionAux(for: $0) } : nil,
                        englishDefinition: vocabularyPreferences.showEnglishDefinition
                            ? usage.flatMap { vocabulary.resolvedDefinitionTarget(for: $0) } : nil,
                        ipa: vocabularyPreferences.showPronunciation ? usage?.ipa : nil,
                        density: vocabularyPreferences.listDensity
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Add Menu

    private var addMenu: some View {
        Menu {
            Button("単語を追加") {
                path.append(VocabularyRoute.add)
            }
            Button("タグを追加") {
                newTagName = ""
                showAddTagAlert = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
    }
}

#Preview {
    VocabularyListScreen()
        .modelContainer(previewContainer)
}
