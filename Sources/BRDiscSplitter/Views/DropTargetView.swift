import SwiftUI
import UniformTypeIdentifiers

struct DropTargetView: View {
  let inputPath: String
  let isDisabled: Bool
  let isScanning: Bool
  let hasMediaPlan: Bool
  let onSelect: () -> Void
  let onDropPath: (String) -> Void

  @State private var isTargeted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(L10n.string("drop.input"))
        .font(.caption)
        .foregroundStyle(.secondary)

      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            borderColor,
            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
          )
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(backgroundColor)
          )

        HStack(spacing: 12) {
          statusIcon
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .font(.body.weight(.medium))
              .lineLimit(1)

            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(inputPath.isEmpty ? 1 : 2)
              .textSelection(.enabled)
          }

          Spacer()

          Button {
            onSelect()
          } label: {
            Label(L10n.string("drop.browse"), systemImage: "folder.badge.plus")
          }
          .controlSize(.small)
          .disabled(isDisabled)
          .help(L10n.string("drop.chooseHelp"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      }
      .frame(height: 82)
      .contentShape(Rectangle())
      .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
        guard !isDisabled else {
          return false
        }

        return loadFirstPath(from: providers)
      }
    }
  }

  private func loadFirstPath(from providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else {
      return false
    }

    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
      guard let data,
        let url = URL(dataRepresentation: data, relativeTo: nil)
      else {
        return
      }

      DispatchQueue.main.async {
        onDropPath(url.path)
      }
    }

    return true
  }

  @ViewBuilder
  private var statusIcon: some View {
    if isScanning {
      ProgressView()
        .controlSize(.small)
    } else {
      Image(systemName: iconName)
        .font(.title3)
        .foregroundColor(iconColor)
    }
  }

  private var title: String {
    guard !inputPath.isEmpty else {
      return L10n.string("drop.emptyTitle")
    }

    return URL(fileURLWithPath: inputPath).lastPathComponent
  }

  private var subtitle: String {
    inputPath.isEmpty ? L10n.string("drop.chooseHelp") : inputPath
  }

  private var iconName: String {
    if hasMediaPlan {
      return "checkmark.circle.fill"
    }

    return inputPath.isEmpty ? "opticaldiscdrive" : "opticaldiscdrive.fill"
  }

  private var iconColor: Color {
    if hasMediaPlan {
      return .green
    }

    return inputPath.isEmpty ? .secondary : .accentColor
  }

  private var borderColor: Color {
    if isTargeted {
      return .accentColor
    }

    if hasMediaPlan {
      return Color.green.opacity(0.65)
    }

    if !inputPath.isEmpty || isScanning {
      return Color.accentColor.opacity(0.65)
    }

    return Color.secondary.opacity(0.35)
  }

  private var backgroundColor: Color {
    if isTargeted {
      return Color.accentColor.opacity(0.1)
    }

    if hasMediaPlan {
      return Color.green.opacity(0.08)
    }

    if !inputPath.isEmpty || isScanning {
      return Color.accentColor.opacity(0.06)
    }

    return Color.clear
  }
}
