import SwiftUI
import UniformTypeIdentifiers

struct DropTargetView: View {
  let inputPath: String
  let isDisabled: Bool
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
            isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
          )
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
          )

        HStack(spacing: 12) {
          Image(systemName: inputPath.isEmpty ? "opticaldiscdrive" : "checkmark.circle")
            .font(.title3)
            .foregroundColor(inputPath.isEmpty ? .secondary : .green)
            .frame(width: 26)

          VStack(alignment: .leading, spacing: 2) {
            Text(inputPath.isEmpty ? L10n.string("drop.emptyTitle") : URL(fileURLWithPath: inputPath).lastPathComponent)
              .font(.body.weight(.medium))
              .lineLimit(1)

            if !inputPath.isEmpty {
              Text(inputPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .frame(height: 64)
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
}
