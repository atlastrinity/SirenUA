import Foundation
import AVFoundation
import AudioToolbox
import OSLog

private let soundLogger = Logger(subsystem: "com.sirenua", category: "SoundPlayer")

final class SoundPlayerManager: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    static let shared = SoundPlayerManager()

    private var audioPlayer: AVAudioPlayer?
    private var audioPlaybackQueue: [URL] = []
    private var isAudioPlaying: Bool = false
    private let audioQueueLock = NSLock()

    private override init() {
        super.init()
    }

    func playSound(named filename: String) {
        guard !filename.isEmpty else { return }

        guard let path = Bundle.main.path(forResource: filename, ofType: nil) else {
            soundLogger.warning("Audio file not found: \(filename)")
            return
        }
        let url = URL(fileURLWithPath: path)

        var shouldStart = false
        audioQueueLock.withLock {
            audioPlaybackQueue.append(url)
            shouldStart = !isAudioPlaying
        }

        if shouldStart {
            playNextAudioInQueue()
        }
    }

    private func playNextAudioInQueue() {
        var nextUrl: URL?
        audioQueueLock.withLock {
            if audioPlaybackQueue.isEmpty {
                isAudioPlaying = false
            } else {
                nextUrl = audioPlaybackQueue.removeFirst()
                isAudioPlaying = true
            }
        }

        guard let nextUrl else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                #if os(iOS)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                #endif
                let player = try AVAudioPlayer(contentsOf: nextUrl)
                player.delegate = self
                self.audioPlayer = player
                player.play()
                soundLogger.info("Playing queued audio: \(nextUrl.lastPathComponent)")
            } catch {
                soundLogger.error("Audio player error: \(error.localizedDescription)")
                self.audioQueueLock.withLock {
                    self.isAudioPlaying = false
                }
                self.playNextAudioInQueue()
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            SoundPlayerManager.shared.audioQueueLock.withLock {
                SoundPlayerManager.shared.isAudioPlaying = false
            }
            SoundPlayerManager.shared.playNextAudioInQueue()
        }
    }
}
