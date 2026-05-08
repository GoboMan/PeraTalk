import SwiftUI

/// 一覧と同じ順序の `remoteId` 列で、`TabView` のページめくりにより詳細を切り替える。
struct VocabularyDetailPagerScreen: View {
    let sequence: [UUID]
    @Binding var path: NavigationPath
    /// 一覧から戻っても維持するため親（例: `VocabularyListScreen`）が保持する。
    @Binding var recallObfuscationModeEnabled: Bool
    @State private var selectionIndex: Int

    init(
        sequence: [UUID],
        currentId: UUID,
        path: Binding<NavigationPath>,
        recallObfuscationModeEnabled: Binding<Bool>
    ) {
        self.sequence = sequence
        self._path = path
        self._recallObfuscationModeEnabled = recallObfuscationModeEnabled
        let idx = sequence.firstIndex(of: currentId) ?? 0
        _selectionIndex = State(initialValue: idx)
    }

    /// スワイプ中に隣ページのツールバーと重ならないよう、ナビバーは親に 1 つだけ載せる。
    private var toolbarVocabularyId: UUID {
        guard !sequence.isEmpty else { return UUID() }
        let clamped = max(0, min(selectionIndex, sequence.count - 1))
        return sequence[clamped]
    }

    /// 1-based。空列時は 0。
    private var positionLabelIndex: Int {
        guard !sequence.isEmpty else { return 0 }
        return max(0, min(selectionIndex, sequence.count - 1)) + 1
    }

    var body: some View {
        TabView(selection: $selectionIndex) {
            ForEach(Array(sequence.enumerated()), id: \.offset) { index, id in
                VocabularyDetailScreen(
                    vocabularyId: id,
                    path: $path,
                    embedsNavigationChrome: false,
                    recallObfuscationModeEnabled: recallObfuscationModeEnabled,
                    pagerFocusedVocabularyId: toolbarVocabularyId
                )
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Vocabulary")
                        .font(.headline)
                    if sequence.count > 1 {
                        Text("\(positionLabelIndex) / \(sequence.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                VocabularyDetailTrailingMenu(
                    path: $path,
                    vocabularyRemoteId: toolbarVocabularyId,
                    recallObfuscationModeEnabled: $recallObfuscationModeEnabled
                )
            }
        }
    }
}
