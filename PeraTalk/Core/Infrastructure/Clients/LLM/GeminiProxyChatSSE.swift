import Foundation

extension URLSession.AsyncBytes {
    /// UTF-8 前提の LF 区切り（CR は捨てる）1 行読み。巨大行は打ち切って返す。
    func linesUTF8(maxLineBytes: Int = 524_288) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { (continuation: AsyncThrowingStream<String, Error>.Continuation) in
            let task = Task {
                do {
                    var line: [UInt8] = []
                    for try await byte in self {
                        if byte == UInt8(ascii: "\n") {
                            let s = String(decoding: line, as: UTF8.self)
                            continuation.yield(s)
                            line = []
                            continue
                        }
                        if byte == UInt8(ascii: "\r") { continue }
                        line.append(byte)
                        if line.count >= maxLineBytes {
                            let s = String(decoding: line, as: UTF8.self)
                            continuation.yield(s)
                            line = []
                        }
                    }
                    if !line.isEmpty {
                        continuation.yield(String(decoding: line, as: UTF8.self))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}