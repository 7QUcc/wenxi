import AVFoundation
import UIKit

/// Keeps the process running while transfers are active. iOS suspends apps a
/// few seconds after they leave the foreground, which would stall the embedded
/// download engine, so a silent mixable audio loop holds the "audio" background
/// mode while there is work. It never ducks or interrupts other audio.
final class BackgroundKeepAlive: NSObject {
  var onExpired: (() -> Void)?

  private var active = false
  private var player: AVAudioPlayer?
  private var task: UIBackgroundTaskIdentifier = .invalid

  override init() {
    super.init()
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(interrupted(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    center.addObserver(
      self, selector: #selector(mediaReset),
      name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    center.addObserver(
      self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }

  func update(active value: Bool) {
    guard value != active else { return }
    active = value
    if value {
      startAudio()
    } else {
      player?.stop()
      player = nil
      endTask()
    }
  }

  private func startAudio() {
    guard active else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      if player == nil {
        let created = try AVAudioPlayer(data: Self.silence)
        created.numberOfLoops = -1
        created.volume = 0
        player = created
      }
      player?.play()
    } catch {
      player = nil
    }
  }

  /// Short grace period for the moment the app leaves the foreground, and the
  /// fallback when audio could not start.
  @objc private func enteredBackground() {
    guard active, task == .invalid else { return }
    task = UIApplication.shared.beginBackgroundTask(withName: "AsterLinkTransfers") { [weak self] in
      guard let self = self else { return }
      if self.active && self.player?.isPlaying != true { self.onExpired?() }
      self.endTask()
    }
  }

  private func endTask() {
    guard task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }

  @objc private func interrupted(_ note: Notification) {
    guard
      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      AVAudioSession.InterruptionType(rawValue: raw) == .ended
    else { return }
    DispatchQueue.main.async { self.startAudio() }
  }

  @objc private func mediaReset() {
    DispatchQueue.main.async {
      self.player = nil
      self.startAudio()
    }
  }

  /// One second of 8 kHz mono 16-bit silence as a WAV file.
  private static let silence: Data = {
    let sampleRate: UInt32 = 8000
    let samples = Int(sampleRate)
    let dataSize = UInt32(samples * 2)
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36) + dataSize)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(1))
    append(sampleRate)
    append(sampleRate * 2)
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(dataSize)
    data.append(Data(count: samples * 2))
    return data
  }()
}
