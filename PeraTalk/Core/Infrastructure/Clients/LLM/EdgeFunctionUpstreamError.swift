import Foundation

enum EdgeFunctionUpstreamError: Error {
    case invalidResponse
    case notEventStreamBody
    case httpStatus(Int, String)
    case streamEnvelope(code: String?, message: String?)
}
