import AppKit
import SwiftUI

struct WindowContentFitPolicy: Equatable {
  var displayPadding: CGFloat = 24

  func targetContentSize(measuredSize: CGSize, visibleFrame: CGRect?) -> CGSize {
    var size = CGSize(
      width: measuredSize.width.rounded(.up),
      height: measuredSize.height.rounded(.up)
    )

    guard let visibleFrame else {
      return size
    }

    let maxWidth = max(1, (visibleFrame.width - displayPadding * 2).rounded(.down))
    let maxHeight = max(1, (visibleFrame.height - displayPadding * 2).rounded(.down))
    size.width = min(size.width, maxWidth)
    size.height = min(size.height, maxHeight)
    return size
  }
}

@MainActor
struct WindowContentFitter {
  var policy = WindowContentFitPolicy()

  func fit(window: NSWindow, to measuredSize: CGSize) {
    guard measuredSize.isUsableWindowContentSize else {
      return
    }

    let targetContentSize = policy.targetContentSize(
      measuredSize: measuredSize,
      visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
    )
    let targetFrame = window.frameRect(forContentRect: CGRect(origin: .zero, size: targetContentSize))

    window.contentMinSize = .zero
    window.contentMaxSize = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )

    if !window.frame.size.isClose(to: targetFrame.size) {
      var frame = window.frame
      let top = frame.maxY
      frame.size = targetFrame.size
      frame.origin.y = top - frame.height
      window.setFrame(frame, display: true, animate: false)
    }

    window.contentMinSize = targetContentSize
    window.contentMaxSize = targetContentSize
  }
}

private struct WindowContentSizePreferenceKey: PreferenceKey {
  static var defaultValue: [String: CGSize] = [:]

  static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

extension View {
  func onMeasuredSizeChange(_ id: String, perform action: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: WindowContentSizePreferenceKey.self,
          value: [id: proxy.size]
        )
      }
    )
    .onPreferenceChange(WindowContentSizePreferenceKey.self) { sizes in
      guard let size = sizes[id], size.isUsableWindowContentSize else {
        return
      }

      action(size)
    }
  }
}

extension CGSize {
  var isUsableWindowContentSize: Bool {
    width.isFinite && height.isFinite && width > 0 && height > 0
  }

  func isClose(to other: CGSize, tolerance: CGFloat = 0.5) -> Bool {
    abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
  }
}
