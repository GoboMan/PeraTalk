import SwiftUI
import SwiftData

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
                case .add(let preselectedTagId):
                    VocabularyAddScreen(preselectedTagId: preselectedTagId)
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
        let items = filteredVocabularies
        let sequence = items.map(\.remoteId)
        return Group {
            if items.isEmpty {
                vocabularyEmptyState
            } else {
                LazyVStack(spacing: vocabularyPreferences.listDensity == .compact ? 6 : 12) {
                    ForEach(items, id: \.remoteId) { vocabulary in
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
        }
    }

    private var vocabularyEmptyState: some View {
        Button {
            path.append(VocabularyRoute.add(preselectedTagId: model.selectedTagId))
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                Text("No Vocabulary")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("追加")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(VocabularyEmptyAddButtonStyle())
        .accessibilityLabel("No Vocabulary、単語を追加")
    }

    // MARK: - Add Menu

    private var addMenu: some View {
        Menu {
            Button("単語を追加") {
                path.append(VocabularyRoute.add(preselectedTagId: model.selectedTagId))
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

private struct VocabularyEmptyAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

#Preview {
    VocabularyListScreen()
        .modelContainer(previewContainer)
}
