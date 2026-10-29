import ActivityKit
import Foundation

/// Shared by the app and the TransferLiveActivity widget extension; both compile
/// this exact file so ActivityKit sees one attributes type.
@available(iOS 16.1, *)
public struct AsterLinkTransferAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// Running transfers, including uploads and LAN transfers.
    public var active: Int
    public var uploads: Int
    /// 0...100, or -1 when the total size is not known yet.
    public var progress: Int
    public var text: String
    public var ended: Bool

    public init(active: Int, uploads: Int, progress: Int, text: String, ended: Bool) {
      self.active = active
      self.uploads = uploads
      self.progress = progress
      self.text = text
      self.ended = ended
    }

    public var title: String {
      if ended { return "传输已结束" }
      if uploads > 0 && uploads >= active { return "正在上传 \(active) 个任务" }
      return "正在传输 \(active) 个任务"
    }

    public var fraction: Double? {
      progress >= 0 ? Double(min(progress, 100)) / 100 : nil
    }
  }

  public init() {}
}
