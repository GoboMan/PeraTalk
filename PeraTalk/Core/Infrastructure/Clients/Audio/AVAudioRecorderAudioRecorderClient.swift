import AVFoundation
import Foundation

/// 16 kHz / mono / 16bit PCM (.wav) でマイク録音し、停止時にファイル URL を返す。
/// Whisper 系モデルが扱いやすいフォーマットに固定している。
@MainActor
final class AVAudioRecorderAudioRecorderClient: NSObject, AudioRecorderClient {
    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?
    /// `audioRecorderDidFinishRecording` で完結する継続。stop() 完了を確実に待つために使う。
    private var finishContinuation: CheckedContinuation<Void, Never>?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording() async throws {
        if recorder?.isRecording == true { return }

        try configureSessionForRecording()

        let url = makeTempFileURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            if !newRecorder.prepareToRecord() {
                throw AudioRecorderError.recordingFailed(underlying: nil)
            }
            if !newRecorder.record() {
                throw AudioRecorderError.recordingFailed(underlying: nil)
            }
            recorder = newRecorder
            currentFileURL = url
        } catch let error as AudioRecorderError {
            throw error
        } catch {
            throw AudioRecorderError.recordingFailed(underlying: error)
        }
    }

    func stopRecording() async throws -> URL {
        guard let recorder, let currentFileURL else {
            throw AudioRecorderError.notRecording
        }
        let urlToReturn = currentFileURL

        // delegate の `didFinishRecording` を必ず 1 回受け取ってから返す。
        // これを待たずに WhisperKit へ渡すと、WAV ヘッダ未確定のままパースに失敗してハングする。
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.finishContinuation = continuation
            recorder.stop()

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                guard let self else { return }
                guard let pending = self.finishContinuation else { return }
                self.finishContinuation = nil
                pending.resume()
            }
        }

        self.recorder = nil
        self.currentFileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return urlToReturn
    }

    func cancelRecording() async {
        guard recorder != nil else {
            if let url = currentFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            currentFileURL = nil
            if let pending = finishContinuation {
                finishContinuation = nil
                pending.resume()
            }
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            return
        }

        let url = currentFileURL
        recorder?.stop()
        recorder = nil
        currentFileURL = nil
        if let pending = finishContinuation {
            finishContinuation = nil
            pending.resume()
        }
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func configureSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true, options: [])
        } catch {
            throw AudioRecorderError.recordingFailed(underlying: error)
        }
    }

    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-\(UUID().uuidString).wav")
    }
}

extension AVAudioRecorderAudioRecorderClient: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        _ = recorder
        _ = flag
        Task { @MainActor [weak self] in
            guard let self else { return }
            let continuation = self.finishContinuation
            self.finishContinuation = nil
            continuation?.resume()
        }
    }
}
