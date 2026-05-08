import CryptoKit
import Foundation
import SwiftData

enum DictionaryPackImportError: Error {
    case checksumMismatch
    case unknownSurfaceFormKind(String)
    case packKeyMismatch
    case emptyLemmaUsages(lemma: String)
    case invalidUsageKind(lemma: String, kind: String)
    case duplicateUsageKind(lemma: String, kind: String)
    case surfaceFormKindMismatch(lemma: String, usageKind: String, formKind: String)
}

// MARK: - DTOs（pack JSON / マニフェスト）

private struct DictionaryPackPayloadDTO: Decodable {
    let packKey: String
    let packVersion: String
    let sha256: String?
    let lemmas: [LemmaPackRowDTO]
}

private struct LemmaPackRowDTO: Decodable {
    let stableLemmaId: UUID
    let lemma: String
    let language: String?
    let usages: [LemmaUsagePackRowDTO]
}

private struct LemmaUsagePackRowDTO: Decodable {
    let kind: String
    let position: Int
    let definitionTarget: String?
    let definitionAux: String?
    let ipa: String?
    let surfaces: [LemmaSurfacePackRowDTO]
}

private struct LemmaSurfacePackRowDTO: Decodable {
    let text: String
    let formKind: String
    let ipa: String?
}

private struct RemotePackManifestDTO: Decodable {
    let packKey: String
    let packVersion: String
    let sha256: String?
    let packDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case packKey = "pack_key"
        case packVersion = "pack_version"
        case sha256
        case packDownloadURL = "pack_download_url"
    }
}

// MARK: - Service

protocol DictionaryPackImportServing {
    /// バンドル内のサンプルパックを、`CachedLemma` が 0 件のときだけ投入する。
    func importEmbeddedSampleIfNeeded(context: ModelContext) throws
    /// マニフェスト URL → ペイロードダウンロード → SHA256 検証（指定時）→ 全レンマ差し替え。
    func downloadAndApplyPack(manifestURL: URL, context: ModelContext) async throws
}

extension Data {
    fileprivate var sha256HexLowercased: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

final class LiveDictionaryPackImportService: DictionaryPackImportServing {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func importEmbeddedSampleIfNeeded(context: ModelContext) throws {
        let count = try context.fetchCount(FetchDescriptor<CachedLemma>())
        guard count == 0 else { return }

        /// 初回投入用の同梱パック。運用で語を増やすたびに更新する（`dictionary_sample_pack.json` は最小スキーマ例の参照用）。
        guard let url = Bundle.main.url(forResource: "dictionary_scaffold_pack", withExtension: "json") else {
            return
        }
        let data = try Data(contentsOf: url)
        try applyPack(payloadData: data, replacingExistingLemmas: false, context: context)
    }

    func downloadAndApplyPack(manifestURL: URL, context: ModelContext) async throws {
        let (manifestData, _) = try await urlSession.data(from: manifestURL)
        let decoder = jsonDecoder()
        let manifest = try decoder.decode(RemotePackManifestDTO.self, from: manifestData)

        let (packData, _) = try await urlSession.data(from: manifest.packDownloadURL)
        if let expected = manifest.sha256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !expected.isEmpty {
            guard packData.sha256HexLowercased == expected else {
                throw DictionaryPackImportError.checksumMismatch
            }
        }

        let payload = try decoder.decode(DictionaryPackPayloadDTO.self, from: packData)
        guard payload.packKey == manifest.packKey else {
            throw DictionaryPackImportError.packKeyMismatch
        }

        try applyPack(payload: payload, rawData: packData, replacingExistingLemmas: true, context: context)
    }

    // MARK: - Core

    private func applyPack(payloadData: Data, replacingExistingLemmas: Bool, context: ModelContext) throws {
        let decoder = jsonDecoder()
        let payload = try decoder.decode(DictionaryPackPayloadDTO.self, from: payloadData)
        if let expected = payload.sha256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !expected.isEmpty {
            guard payloadData.sha256HexLowercased == expected else {
                throw DictionaryPackImportError.checksumMismatch
            }
        }
        try applyPack(payload: payload, rawData: payloadData, replacingExistingLemmas: replacingExistingLemmas, context: context)
    }

    private func applyPack(
        payload: DictionaryPackPayloadDTO,
        rawData: Data,
        replacingExistingLemmas: Bool,
        context: ModelContext
    ) throws {
        if replacingExistingLemmas {
            let existing = try context.fetch(FetchDescriptor<CachedLemma>())
            existing.forEach { context.delete($0) }
        }

        try insertLemmas(from: payload, context: context)
        try upsertPackMeta(payload: payload, contentSHA256: rawData.sha256HexLowercased, context: context)
        try context.save()
    }

    private func insertLemmas(from payload: DictionaryPackPayloadDTO, context: ModelContext) throws {
        for row in payload.lemmas {
            guard !row.usages.isEmpty else {
                throw DictionaryPackImportError.emptyLemmaUsages(lemma: row.lemma)
            }

            let sortedPackUsages = row.usages.sorted { $0.position < $1.position }
            var seenKinds = Set<String>()
            for usageRow in sortedPackUsages {
                guard let vocabularyKind = resolvedVocabularyKind(usageRow.kind) else {
                    throw DictionaryPackImportError.invalidUsageKind(lemma: row.lemma, kind: usageRow.kind)
                }
                guard seenKinds.insert(vocabularyKind.rawValue).inserted else {
                    throw DictionaryPackImportError.duplicateUsageKind(lemma: row.lemma, kind: usageRow.kind)
                }
                for surface in usageRow.surfaces {
                    guard let formKind = LemmaSurfaceFormKind(rawValue: surface.formKind) else {
                        throw DictionaryPackImportError.unknownSurfaceFormKind(surface.formKind)
                    }
                    guard formKind.isCompatible(withUsageKind: vocabularyKind) else {
                        throw DictionaryPackImportError.surfaceFormKindMismatch(
                            lemma: row.lemma,
                            usageKind: usageRow.kind,
                            formKind: surface.formKind
                        )
                    }
                }
            }

            let lemma = CachedLemma(
                stableLemmaId: row.stableLemmaId,
                lemmaText: row.lemma,
                languageCode: row.language ?? "en"
            )
            context.insert(lemma)

            for usageRow in sortedPackUsages {
                guard let vocabularyKind = resolvedVocabularyKind(usageRow.kind) else {
                    throw DictionaryPackImportError.invalidUsageKind(lemma: row.lemma, kind: usageRow.kind)
                }
                let usage = CachedLemmaUsage(
                    kind: vocabularyKind.rawValue,
                    position: usageRow.position,
                    definitionTarget: usageRow.definitionTarget,
                    definitionAux: usageRow.definitionAux,
                    ipa: usageRow.ipa
                )
                usage.lemma = lemma
                context.insert(usage)

                for surface in usageRow.surfaces {
                    let s = CachedLemmaSurface(text: surface.text, formKindRaw: surface.formKind, ipa: surface.ipa)
                    s.usage = usage
                    context.insert(s)
                }
            }
        }
    }

    private func resolvedVocabularyKind(_ raw: String) -> VocabularyKind? {
        if let k = VocabularyKind(rawValue: raw) { return k }
        return VocabularyKind(kindString: raw)
    }

    private func upsertPackMeta(
        payload: DictionaryPackPayloadDTO,
        contentSHA256: String,
        context: ModelContext
    ) throws {
        let packKey = payload.packKey
        var descriptor = FetchDescriptor<CachedDictionaryPackMeta>()
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate<CachedDictionaryPackMeta> { $0.packKey == packKey }
        if let meta = try context.fetch(descriptor).first {
            meta.installedVersion = payload.packVersion
            meta.installedContentSHA256 = contentSHA256
            meta.installedAt = Date()
        } else {
            context.insert(
                CachedDictionaryPackMeta(
                    packKey: payload.packKey,
                    installedVersion: payload.packVersion,
                    installedContentSHA256: contentSHA256
                )
            )
        }
    }

    private func jsonDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}

/// ユニットテストやスタブ用途：インメモリのみの no-op に近い挙動。
struct StubDictionaryPackImportService: DictionaryPackImportServing {
    func importEmbeddedSampleIfNeeded(context: ModelContext) throws {}
    func downloadAndApplyPack(manifestURL: URL, context: ModelContext) async throws {}
}
