import Foundation

enum SubscriptionStatus: String, Codable {
    case active
    case inGrace = "in_grace"
    case canceled
    case expired
    case revoked
}
