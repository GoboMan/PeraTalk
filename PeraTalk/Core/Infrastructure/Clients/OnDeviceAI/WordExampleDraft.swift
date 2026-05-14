import Foundation

/// 用法スロットごとの例文グループ（`VocabularyKind` 名と順序で対応付ける）。
struct WordExampleDraft: Sendable {
    let groups: [WordExampleDraftGroup]
}
