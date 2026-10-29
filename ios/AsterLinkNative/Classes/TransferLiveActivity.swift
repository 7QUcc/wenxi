import ActivityKit
import Foundation

/// Mirrors the transfer notice Dart publishes through `foreground` onto a Live
/// Activity (Dynamic Island and Lock Screen). Updates are coalesced to at most
/// one per second; ActivityKit throttles anything faster anyway.
final class TransferLiveActivity {
  private var activity: Any?
  private var lastSent: Any?
  private var lastTime = Date.distantPast
  private var trailing: DispatchWorkItem?

  init() {
    guard #available(iOS 16.2, *) else { return }
    // A previous process may have been killed with an activity still showing.
    for stale in Activity<AsterLinkTransferAttributes>.activities {
      Task { await stale.end(nil, dismissalPolicy: .immediate) }
    }
  }

  func update(_ args: [String: Any]) {
    guard #available(iOS 16.2, *) else { return }
    let state = AsterLinkTransferAttributes.ContentState(
      active: (args["active"] as? NSNumber)?.intValue ?? 0,
      uploads: (args["uploads"] as? NSNumber)?.intValue ?? 0,
      progress: (args["progress"] as? NSNumber)?.intValue ?? -1,
      text: args["text"] as? String ?? "",
      ended: false)
    trailing?.cancel()
    trailing = nil
    if state.active <= 0 {
      end()
      return
    }
    let wait = 1 - Date().timeIntervalSince(lastTime)
    if wait > 0 && activity != nil {
      let work = DispatchWorkItem { [weak self] in self?.send(state) }
      trailing = work
      DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: work)
      return
    }
    send(state)
  }

  /// Ends immediately; used when the app is about to terminate.
  func endNow() {
    guard #available(iOS 16.2, *), let current = activity as? Activity<AsterLinkTransferAttributes>
    else { return }
    activity = nil
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached {
      await current.end(nil, dismissalPolicy: .immediate)
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 1)
  }

  @available(iOS 16.2, *)
  private func send(_ state: AsterLinkTransferAttributes.ContentState) {
    if let last = lastSent as? AsterLinkTransferAttributes.ContentState, last == state,
      activity != nil
    {
      return
    }
    lastTime = Date()
    let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
    if let current = activity as? Activity<AsterLinkTransferAttributes>,
      current.activityState == .active
    {
      lastSent = state
      Task { await current.update(content) }
      return
    }
    // Requests are only allowed while the app is in the foreground; a failed
    // request is retried on the next update.
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    do {
      activity = try Activity<AsterLinkTransferAttributes>.request(
        attributes: AsterLinkTransferAttributes(), content: content, pushType: nil)
      lastSent = state
    } catch {
      activity = nil
      lastSent = nil
    }
  }

  private func end() {
    guard #available(iOS 16.2, *), let current = activity as? Activity<AsterLinkTransferAttributes>
    else { return }
    activity = nil
    lastSent = nil
    let last = current.content.state
    let final = AsterLinkTransferAttributes.ContentState(
      active: 0, uploads: 0, progress: last.progress, text: "进度已保存，可在传输页查看", ended: true)
    Task {
      await current.end(
        ActivityContent(state: final, staleDate: nil),
        dismissalPolicy: .after(Date().addingTimeInterval(4)))
    }
  }
}
