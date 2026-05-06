import Foundation

protocol PronunciationRepository {
    func lookupIPA(for word: String) -> String?
}
