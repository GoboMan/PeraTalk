import Foundation

enum VocabularyRoute: Hashable {
    /// 一覧で表示中だった順序と、開く単語の ID（横スワイプで `sequence` 内を移動）。
    case detail(sequence: [UUID], currentId: UUID)
    /// 一覧でタグフィルタ中に追加した場合、そのタグを既定で選択する。
    case add(preselectedTagId: UUID?)
    case edit(UUID)
}
