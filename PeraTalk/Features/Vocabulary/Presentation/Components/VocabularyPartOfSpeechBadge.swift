import SwiftUI

/// 単語一覧・詳細（用法カード）で共通の品詞ラベル。
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
