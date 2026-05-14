import SwiftData
import SwiftUI

/// 辞典レマの活用を、見出しなし・ラベル付きで 1 ブロックにまとめて表示する（単語詳細の用法カード内）。
struct LemmaInflectionCompactBlockView: View {
    let usage: CachedLemmaUsage

    private var rows: [(label: String, text: String, ipa: String?)] {
        LemmaParadigmPresenter.rows(for: usage)
    }

    var body: some View {
        Group {
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)

                            Text(row.text)
                                .font(.body)
                                .fontWeight(.medium)

                            if let ipa = row.ipa, !ipa.isEmpty {
                                Text(ipa)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)

                        if index < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.top, 12)
            }
        }
    }
}
