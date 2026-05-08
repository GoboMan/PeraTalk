import SwiftUI

/// 品詞ラベル（単語詳細の用法カードなど）。一覧カードでは表示しない。
struct VocabularyPartOfSpeechBadge: View {
    var kind: VocabularyKind?

    var body: some View {
        if let kind {
            Text(kind.englishLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(kind.badgeColor.opacity(0.15))
                .foregroundStyle(kind.badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
