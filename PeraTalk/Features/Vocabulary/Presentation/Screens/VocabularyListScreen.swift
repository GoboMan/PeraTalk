import SwiftUI
import SwiftData

enum VocabularyRoute: Hashable {
    case detail(UUID)
    case add
    case edit(UUID)
}

struct VocabularyListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supabaseTableClient) private var supabaseTableClient
    @State private var model = VocabularyListScreenModel()
    @State private var path = NavigationPath()
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
                model = VocabularyListScreenModel.live(
                    modelContext: modelContext,
                    supabaseTableClient: supabaseTableClient
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .searchable(text: $model.searchQuery, prompt: "単語を検索")
            .navigationDestination(for: VocabularyRoute.self) { route in
                switch route {
                case .detail(let id):
                    VocabularyDetailScreen(vocabularyId: id, path: $path)
                case .add:
                    VocabularyAddScreen()
                case .edit(let id):
                    VocabularyAddScreen(vocabularyId: id)
                }
            }
            .alert("辞書パック", isPresented: Binding(
                get: { model.remoteDictionaryPackBanner != nil },
                set: { if !$0 { model.remoteDictionaryPackBanner = nil } }
            )) {
                Button("OK") { model.remoteDictionaryPackBanner = nil }
            } message: {
                Text(model.remoteDictionaryPackBanner ?? "")
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
        LazyVStack(spacing: vocabularyPreferences.listDensity == .compact ? 6 : 12) {
            ForEach(filteredVocabularies, id: \.remoteId) { vocabulary in
                let usage = model.firstUsage(of: vocabulary)
                NavigationLink(value: VocabularyRoute.detail(vocabulary.remoteId)) {
                    VocabularyCardView(
                        headword: vocabulary.headword,
                        showPartOfSpeech: vocabularyPreferences.showPartOfSpeech,
                        kind: usage.flatMap { VocabularyKind(kindString: $0.kind) },
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
            Button("サーバーから辞書を同期", systemImage: "arrow.down.circle") {
                Task {
                    await model.syncRemoteDictionaryPackFromCatalog(context: modelContext)
                }
            }
            .disabled(model.isSyncingRemoteDictionaryPack)
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
