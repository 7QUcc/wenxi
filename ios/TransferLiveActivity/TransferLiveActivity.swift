import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TransferLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    TransferLiveActivityWidget()
  }
}

private let accent = Color(red: 0.10, green: 0.46, blue: 0.98)

struct TransferLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AsterLinkTransferAttributes.self) { context in
      LockScreenView(state: context.state)
        .activitySystemActionForegroundColor(accent)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          StatusIcon(state: state)
            .font(.title2)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(state.percentText)
            .font(.title3.monospacedDigit().weight(.semibold))
            .foregroundStyle(accent)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(state.title)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            ProgressBar(fraction: state.fraction)
            Text(state.text)
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        StatusIcon(state: state)
      } compactTrailing: {
        Text(state.percentText)
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(accent)
      } minimal: {
        ProgressRing(fraction: state.fraction)
          .padding(2)
      }
      .keylineTint(accent)
    }
  }
}

private struct LockScreenView: View {
  let state: AsterLinkTransferAttributes.ContentState

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        ProgressRing(fraction: state.fraction)
        StatusIcon(state: state).font(.body)
      }
      .frame(width: 44, height: 44)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(state.title).font(.headline).lineLimit(1)
          Spacer()
          Text(state.percentText)
            .font(.subheadline.monospacedDigit().weight(.semibold))
            .foregroundStyle(accent)
        }
        ProgressBar(fraction: state.fraction)
        Text(state.text)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(16)
  }
}

private struct StatusIcon: View {
  let state: AsterLinkTransferAttributes.ContentState

  var body: some View {
    Image(systemName: icon)
      .foregroundStyle(accent)
  }

  private var icon: String {
    if state.ended { return "checkmark.circle.fill" }
    if state.uploads > 0 && state.uploads >= state.active { return "arrow.up.circle.fill" }
    return "arrow.down.circle.fill"
  }
}

private struct ProgressBar: View {
  let fraction: Double?

  var body: some View {
    if let fraction {
      ProgressView(value: fraction).tint(accent)
    } else {
      ProgressView(value: 0.0).tint(accent).opacity(0.4)
    }
  }
}

private struct ProgressRing: View {
  let fraction: Double?

  var body: some View {
    ZStack {
      Circle().stroke(accent.opacity(0.25), lineWidth: 3)
      Circle()
        .trim(from: 0, to: fraction ?? 0.08)
        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

extension AsterLinkTransferAttributes.ContentState {
  fileprivate var percentText: String {
    if progress >= 0 { return "\(min(progress, 100))%" }
    return ended ? "—" : "…"
  }
}
