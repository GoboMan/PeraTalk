import SwiftUI

struct ExampleRowView: View {
    let sentence: String
    /// 設定の翻訳先言語に合わせたラベル（例: 「和訳」）。`nil` のときは英文のみ表示。
    var translatedLineTitle: String? = nil
    let translation: String?
    /// 英文の下に境界線＋訳エリアを付けるか（補助言語が英語以外のとき）。
    var showsTranslationAttachment: Bool = false
    /// フレームワークの翻訳取得中。
    var isTranslating: Bool = false

    private var trimmedSentence: String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sentence)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsTranslationAttachment, !trimmedSentence.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)

                    if isTranslating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("読み込み中…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    } else {
                        if let translatedLineTitle, !translatedLineTitle.isEmpty {
                            Text(translatedLineTitle)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.tertiary)
                        }
                        if let translation, !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(translation)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("翻訳を表示できませんでした")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
