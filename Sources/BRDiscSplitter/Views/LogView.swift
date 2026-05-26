import SwiftUI

struct LogView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.string("log.title"))
            .font(.headline)

          Text(model.statusText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer()

        Button {
          model.copyLog()
        } label: {
          Image(systemName: "doc.on.doc")
        }
        .disabled(model.logText.isEmpty)
        .help(L10n.string("log.copy"))

        Button {
          model.clearLog()
        } label: {
          Image(systemName: "trash")
        }
        .disabled(model.logText.isEmpty || model.isRunning)
        .help(L10n.string("log.clear"))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider()

      ScrollViewReader { proxy in
        ScrollView {
          if model.logText.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "terminal")
                .font(.title2)
                .foregroundStyle(.secondary)

              Text(L10n.string("log.empty"))
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
          } else {
            Text(model.logText)
              .font(.system(size: 12, design: .monospaced))
              .lineSpacing(2)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .padding(14)
          }

          Color.clear
            .frame(height: 1)
            .id("log-bottom")
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: model.logText) { _ in
          withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo("log-bottom", anchor: .bottom)
          }
        }
      }
    }
  }
}
