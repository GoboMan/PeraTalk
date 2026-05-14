import Foundation

enum DictionaryPackImportError: Error {
    case checksumMismatch
    case unknownSurfaceFormKind(String)
    case packKeyMismatch
    case emptyLemmaUsages(lemma: String)
    case invalidUsageKind(lemma: String, kind: String)
    case duplicateUsageKind(lemma: String, kind: String)
    case surfaceFormKindMismatch(lemma: String, usageKind: String, formKind: String)
}
