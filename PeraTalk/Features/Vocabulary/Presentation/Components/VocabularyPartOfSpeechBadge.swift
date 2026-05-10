import SwiftUI

/// 単語一覧（任意）、辞典候補、単語追加・編集フォーム、単語詳細の用法ヘッダーなど。
/// 英語ラベル＋品詞ごとの塗り色のキャプセルで統一する。
struct VocabularyPartOfSpeechCapsuleChip: View {
    var kind: VocabularyKind

    var body: some View {
        Text(kind.englishLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(Capsule().fill(kind.badgeColor))
            .fixedSize()
    }
}
