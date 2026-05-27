import AppKit
import SwiftUI

struct ContentView: View {
  private enum Layout {
    static let controlsWidth: CGFloat = 680
    static let logWidth: CGFloat = 520
  }

  private enum SizeID {
    static let content = "content"
    static let wizard = "wizard"
  }

  static let launchFallbackContentSize = CGSize(width: Layout.controlsWidth, height: 360)

  private enum WizardStep: Equatable {
    case input
    case options
    case confirm
    case complete

    var title: String {
      switch self {
      case .input:
        return L10n.string("wizard.step.input.title")
      case .options:
        return L10n.string("wizard.step.options.title")
      case .confirm:
        return L10n.string("wizard.step.confirm.title")
      case .complete:
        return L10n.string("wizard.step.complete.title")
      }
    }
  }

  @ObservedObject var model: AppModel
  @State private var step: WizardStep = .input
  @State private var isAdvancedExpanded = false
  @State private var isLogVisible = false
  @State private var window: NSWindow?
  @State private var pendingAdvanceAfterScan = false
  @State private var measuredContentSize: CGSize = .zero
  @State private var measuredWizardHeight: CGFloat = 0

  var body: some View {
    content
      .frame(width: preferredContentWidth)
      .fixedSize(horizontal: false, vertical: true)
      .onMeasuredSizeChange(SizeID.content) { size in
        measuredContentSize = size
        fitWindow(to: size)
      }
      .transaction { transaction in
        transaction.animation = nil
        transaction.disablesAnimations = true
      }
      .background(
        WindowAccessor { window in
          attachWindow(window)
        }
      )
      .onChange(of: model.options) { _ in
        model.refreshValidationStatus()
      }
      .onChange(of: model.isScanning) { isScanning in
        handleScanStateChange(isScanning: isScanning)
      }
      .onChange(of: model.isRunning) { isRunning in
        handleRunStateChange(isRunning: isRunning)
      }
  }

  private var content: some View {
    Group {
      if isLogVisible {
        HStack(spacing: 0) {
          measuredWizardPane

          LogView(model: model)
            .frame(width: Layout.logWidth, height: logPanelHeight)
        }
      } else {
        measuredWizardPane
      }
    }
  }

  private var measuredWizardPane: some View {
    wizardPane
      .frame(width: preferredPaneWidth)
      .fixedSize(horizontal: false, vertical: true)
      .onMeasuredSizeChange(SizeID.wizard) { size in
        measuredWizardHeight = size.height
      }
  }

  private var wizardPane: some View {
    VStack(spacing: 0) {
      header

      Divider()

      stepBody
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)

      Divider()

      footer
        .padding(16)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Label {
          VStack(alignment: .leading, spacing: 1) {
            Text("BRDisc Splitter")
              .font(.headline)

            Text(AppVersion.displayText)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "opticaldiscdrive")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }

        Spacer()

        StatusBadge(text: model.statusText, tone: statusTone)

        LanguagePicker(language: $model.language)

        Button {
          setLogVisibility(!isLogVisible)
        } label: {
          Image(systemName: "sidebar.right")
        }
        .help(isLogVisible ? L10n.string("log.hide") : L10n.string("log.show"))
      }

      stepProgress
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var stepProgress: some View {
    HStack(alignment: .center, spacing: 8) {
      ForEach(Array(breadcrumbSteps.enumerated()), id: \.offset) { index, breadcrumbStep in
        StepToken(
          number: index + 1,
          title: breadcrumbStep.title,
          state: stepTokenState(for: index)
        )

        if index < breadcrumbSteps.count - 1 {
          Rectangle()
            .fill(index < currentBreadcrumbIndex ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.2))
            .frame(width: 18, height: 1)
        }
      }
    }
  }

  private var breadcrumbSteps: [WizardStep] {
    [.input, .options, .confirm, .complete]
  }

  private var currentBreadcrumbIndex: Int {
    breadcrumbSteps.firstIndex(of: step) ?? breadcrumbSteps.count - 1
  }

  private func stepTokenState(for index: Int) -> StepToken.State {
    if index < currentBreadcrumbIndex {
      return .done
    }

    if index == currentBreadcrumbIndex {
      return .current
    }

    return .pending
  }

  @ViewBuilder
  private var stepBody: some View {
    switch step {
    case .input:
      inputStep
    case .options:
      optionsStep
    case .confirm:
      confirmStep
    case .complete:
      completeStep
    }
  }

  private var inputStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      DropTargetView(
        inputPath: model.options.inputPath,
        isDisabled: model.isBusy,
        isScanning: model.isScanning,
        hasMediaPlan: model.hasMediaPlan,
        onSelect: model.chooseInput,
        onDropPath: model.setDroppedInput(path:)
      )

      if model.isScanning {
        HStack(spacing: 10) {
          ProgressView()
            .controlSize(.small)

          Text(L10n.string("status.scanningMedia"))
            .foregroundStyle(.secondary)
        }
      }

      if let message = model.scanMessage, !model.isScanning {
        VStack(alignment: .leading, spacing: 8) {
          Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)

          Button {
            setLogVisibility(true)
          } label: {
            Label(L10n.string("log.show"), systemImage: "sidebar.right")
          }
          .controlSize(.small)
          .disabled(model.logText.isEmpty)
        }
      }

      if model.hasMediaPlan {
        MediaPlanListView(
          plan: model.mediaPlan,
          openingItemID: model.openingItemID,
          onOpen: model.openMediaItem(_:)
        )
      }
    }
  }

  private var optionsStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      outputDirectoryField

      VStack(alignment: .leading, spacing: 6) {
        Text(L10n.string("field.mediaName"))
          .font(.caption)
          .foregroundStyle(.secondary)

        TextField(L10n.string("field.mediaName.placeholder"), text: $model.options.mediaName)
          .textFieldStyle(.roundedBorder)
          .disabled(model.isBusy)
      }

      commonOptions

      DisclosureGroup(L10n.string("section.advanced"), isExpanded: advancedExpansion) {
        advancedOptions
          .padding(.top, 8)
      }
      .transaction { transaction in
        transaction.animation = nil
        transaction.disablesAnimations = true
      }

      if model.isScanning {
        HStack(spacing: 10) {
          ProgressView()
            .controlSize(.small)

          Text(L10n.string("status.rescanningWithOptions"))
            .foregroundStyle(.secondary)
        }
      } else if let message = model.scanMessage, model.needsPlanRefresh {
        Label(message, systemImage: "arrow.clockwise")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var outputDirectoryField: some View {
    VStack(alignment: .leading, spacing: 8) {
      pathField(
        title: L10n.string("field.outputDirectory"),
        text: $model.options.outputDirectory,
        systemImage: "folder",
        action: model.chooseOutputDirectory
      )

      if model.inputISOParentDirectory != nil {
        Button {
          model.useInputISOParentDirectoryForOutput()
        } label: {
          Label(L10n.string("option.outputSameAsISO"), systemImage: "opticaldiscdrive")
        }
        .controlSize(.small)
        .disabled(model.isBusy)
        .help(L10n.string("option.outputSameAsISO.help"))
      }
    }
  }

  private var confirmStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      SummaryRows(model: model)

      MediaPlanListView(
        plan: model.mediaPlan,
        openingItemID: model.openingItemID,
        onOpen: model.openMediaItem(_:)
      )

      if model.isRunning {
        VStack(alignment: .leading, spacing: 8) {
          ProgressView(value: model.progress.fraction)

          HStack {
            Text(model.options.dryRun ? L10n.string("progress.preview") : L10n.string("progress.extracting"))
            Spacer()
            Text(model.progress.displayText)
              .monospacedDigit()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      } else if let exitCode = model.lastExitCode, exitCode != 0 {
        VStack(alignment: .leading, spacing: 8) {
          Label(L10n.format("error.extractionFailed", exitCode), systemImage: "xmark.octagon")
            .foregroundStyle(.red)

          Button {
            setLogVisibility(true)
          } label: {
            Label(L10n.string("log.show"), systemImage: "sidebar.right")
          }
          .controlSize(.small)
          .disabled(model.logText.isEmpty)
        }
      }
    }
  }

  private var completeStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(L10n.string("complete.title"), systemImage: "checkmark.circle")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundStyle(.green)

      if let summary = model.completionSummary {
        if summary.isDryRun {
          Text(L10n.format("complete.dryRunSummary", summary.plannedCount))
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Text(L10n.format("complete.summary", summary.fileCount, summary.formattedBytes))
            .fixedSize(horizontal: false, vertical: true)
        }

        Text(summary.outputDirectory)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .lineLimit(2)
      } else {
        Text(L10n.string("complete.ended"))
      }
    }
  }

  private var commonOptions: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle(L10n.string("option.dryRun"), isOn: $model.options.dryRun)
        .disabled(model.isBusy)

      DescribedToggle(
        title: L10n.string("option.overwrite"),
        description: L10n.string("option.overwrite.description"),
        isOn: $model.options.overwrite,
        isDisabled: model.isBusy
      )
    }
  }

  private var advancedOptions: some View {
    VStack(alignment: .leading, spacing: 12) {
      ParameterStepper(
        title: L10n.string("option.season"),
        value: $model.options.season,
        range: 1...999,
        step: 1,
        isDisabled: model.isBusy
      )

      ParameterStepper(
        title: L10n.string("option.episodeStart"),
        value: $model.options.episodeStart,
        range: 1...999,
        step: 1,
        isDisabled: model.isBusy
      )

      ParameterStepper(
        title: L10n.string("option.jobs"),
        value: $model.options.jobs,
        range: 1...32,
        step: 1,
        isDisabled: model.isBusy
      )

      ParameterStepper(
        title: L10n.string("option.minDuration"),
        value: $model.options.minDuration,
        range: 1...86_400,
        step: 60,
        suffix: L10n.string("unit.seconds"),
        isDisabled: model.isBusy
      )

      Toggle(L10n.string("option.noMediaDir"), isOn: $model.options.noMediaDir)
        .disabled(model.isBusy)

      Toggle(L10n.string("option.noSeasonDir"), isOn: $model.options.noSeasonDir)
        .disabled(model.isBusy)

      DescribedToggle(
        title: L10n.string("option.originalContainer"),
        description: L10n.string("option.originalContainer.description"),
        isOn: $model.options.useOriginalMediaContainer,
        isDisabled: model.isBusy
      )

      pathField(
        title: L10n.string("field.cliScript"),
        text: $model.options.cliPath,
        systemImage: "terminal",
        action: model.chooseCLIPath
      )
    }
  }

  private var footer: some View {
    HStack(spacing: 12) {
      switch step {
      case .input:
        Spacer()

        Button(L10n.string("button.next")) {
          setStep(.options)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!model.hasMediaPlan || model.isBusy)

      case .options:
        Button(L10n.string("button.back")) {
          setStep(.input)
        }
        .disabled(model.isBusy)

        Spacer()

        Button(model.needsPlanRefresh ? L10n.string("button.rescanAndContinue") : L10n.string("button.next")) {
          continueFromOptions()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(model.validationMessage != nil || model.isBusy)

      case .confirm:
        Button(L10n.string("button.back")) {
          setStep(.options)
        }
        .disabled(model.isRunning)

        Spacer()

        Button(L10n.string("button.cancel")) {
          model.cancel()
        }
        .disabled(!model.isRunning)

        Button(model.isRunning ? L10n.string("button.running") : L10n.string("button.start")) {
          startExtraction()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canStart)

      case .complete:
        Button(L10n.string("button.openInFinder")) {
          model.openOutputInFinder()
        }

        Spacer()

        Button(L10n.string("button.newTask")) {
          model.resetForNewTask()
          setStep(.input)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)

        Button(L10n.string("button.quit")) {
          model.quit()
        }
      }
    }
  }

  private var preferredPaneWidth: CGFloat {
    Layout.controlsWidth
  }

  private var preferredContentWidth: CGFloat {
    preferredPaneWidth + (isLogVisible ? Layout.logWidth : 0)
  }

  private var logPanelHeight: CGFloat {
    max(1, measuredWizardHeight.rounded(.up))
  }


  private var advancedExpansion: Binding<Bool> {
    Binding(
      get: { isAdvancedExpanded },
      set: { setAdvancedVisibility($0) }
    )
  }

  private var statusTone: StatusBadge.Tone {
    if model.isRunning || model.isScanning || model.isOpening {
      return .active
    }

    if let exitCode = model.lastExitCode, exitCode != 0 {
      return .error
    }

    if model.validationMessage != nil || model.scanMessage != nil {
      return .warning
    }

    return .success
  }

  private func pathField(
    title: String,
    text: Binding<String>,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        TextField(title, text: text)
          .textFieldStyle(.roundedBorder)
          .disabled(model.isBusy)

        Button(action: action) {
          Image(systemName: systemImage)
        }
        .disabled(model.isBusy)
        .help(title)
      }
    }
  }

  private func continueFromOptions() {
    guard model.needsPlanRefresh else {
      setStep(.confirm)
      return
    }

    pendingAdvanceAfterScan = true
    model.scanInput()
  }

  private func startExtraction() {
    model.start()
  }

  private func handleScanStateChange(isScanning: Bool) {
    if !isScanning, pendingAdvanceAfterScan {
      pendingAdvanceAfterScan = false

      if model.hasMediaPlan {
        setStep(.confirm)
      }
    }
  }

  private func handleRunStateChange(isRunning: Bool) {
    if !isRunning, model.lastExitCode == 0, model.completionSummary != nil {
      setStep(.complete)
      return
    }
  }

  private func setStep(_ newStep: WizardStep) {
    guard step != newStep else {
      return
    }

    withoutAnimation {
      step = newStep
    }
  }

  private func setLogVisibility(_ visible: Bool) {
    guard visible != isLogVisible else {
      return
    }

    withoutAnimation {
      isLogVisible = visible
    }
  }

  private func setAdvancedVisibility(_ visible: Bool) {
    guard visible != isAdvancedExpanded else {
      return
    }

    withoutAnimation {
      isAdvancedExpanded = visible
    }
  }

  private func withoutAnimation(_ update: () -> Void) {
    var transaction = Transaction()
    transaction.animation = nil
    transaction.disablesAnimations = true

    withTransaction(transaction) {
      update()
    }
  }

  private func attachWindow(_ window: NSWindow) {
    guard self.window !== window else {
      return
    }

    self.window = window
    window.isRestorable = false
    fitWindow()
  }

  private func fitWindow(to measuredSize: CGSize? = nil) {
    guard let window else {
      return
    }

    let size = measuredSize ?? measuredContentSize
    guard size.isUsableWindowContentSize else {
      return
    }

    DispatchQueue.main.async {
      WindowContentFitter().fit(window: window, to: size)
    }
  }
}

private struct StepToken: View {
  enum State {
    case done
    case current
    case pending
  }

  let number: Int
  let title: String
  let state: State

  var body: some View {
    HStack(spacing: 6) {
      ZStack {
        Circle()
          .fill(markerFill)

        if state == .done {
          Image(systemName: "checkmark")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.white)
        } else {
          Text("\(number)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(markerText)
        }
      }
      .frame(width: 18, height: 18)

      Text(title)
        .font(.caption.weight(state == .current ? .semibold : .regular))
        .foregroundStyle(titleStyle)
        .lineLimit(1)
    }
  }

  private var markerFill: Color {
    switch state {
    case .done:
      return Color.accentColor
    case .current:
      return Color.accentColor.opacity(0.18)
    case .pending:
      return Color.secondary.opacity(0.14)
    }
  }

  private var markerText: Color {
    state == .current ? Color.accentColor : Color.secondary
  }

  private var titleStyle: some ShapeStyle {
    switch state {
    case .done:
      return AnyShapeStyle(Color.accentColor)
    case .current:
      return AnyShapeStyle(.primary)
    case .pending:
      return AnyShapeStyle(.secondary)
    }
  }
}

private struct StatusBadge: View {
  enum Tone {
    case active
    case success
    case warning
    case error
  }

  let text: String
  let tone: Tone

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.caption)
      .lineLimit(2)
      .foregroundStyle(foreground)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(background)
      )
      .frame(maxWidth: 220, alignment: .trailing)
  }

  private var systemImage: String {
    switch tone {
    case .active:
      return "hourglass"
    case .success:
      return "checkmark.circle.fill"
    case .warning:
      return "exclamationmark.triangle.fill"
    case .error:
      return "xmark.octagon.fill"
    }
  }

  private var foreground: Color {
    switch tone {
    case .active:
      return .primary
    case .success:
      return .green
    case .warning:
      return .secondary
    case .error:
      return .red
    }
  }

  private var background: Color {
    switch tone {
    case .active:
      return Color.accentColor.opacity(0.12)
    case .success:
      return Color.green.opacity(0.12)
    case .warning:
      return Color.secondary.opacity(0.12)
    case .error:
      return Color.red.opacity(0.12)
    }
  }
}

private struct LanguagePicker: View {
  @Binding var language: AppLanguage

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "globe")
        .foregroundStyle(.secondary)
        .help(L10n.string("language.label"))

      Picker(L10n.string("language.label"), selection: $language) {
        ForEach(AppLanguage.allCases) { language in
          Text(language.displayName)
            .tag(language)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(width: 118)
    }
  }
}

private enum AppVersion {
  static let displayText: String = {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = value(for: "CFBundleShortVersionString", in: info)
    let buildNumber = value(for: "CFBundleVersion", in: info)
    let gitShort = value(for: "BRDiscGitShortHash", in: info)

    return "v\(version) (\(buildNumber)) | \(gitShort)"
  }()

  private static func value(for key: String, in info: [String: Any]) -> String {
    guard let value = info[key] as? String, !value.isEmpty else {
      return "unknown"
    }

    return value
  }
}

private struct WindowAccessor: NSViewRepresentable {
  let onResolve: (NSWindow) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      if let window = view.window {
        onResolve(window)
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      if let window = nsView.window {
        onResolve(window)
      }
    }
  }
}

private struct MediaPlanListView: View {
  let plan: MediaPlan
  var openingItemID: String?
  var onOpen: ((MediaPlanItem) -> Void)?

  private static let rowHeight: CGFloat = 128
  private static let rowSpacing: CGFloat = 6
  private static let maxVisibleRows = 4

  private static func visibleRowsHeight(itemCount: Int) -> CGFloat {
    rowsHeight(min(itemCount, maxVisibleRows))
  }

  private static func rowsHeight(_ rowCount: Int) -> CGFloat {
    guard rowCount > 0 else {
      return 0
    }

    return CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * rowSpacing
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(L10n.format("mediaPlan.identifiedAs", plan.mediaTypeDisplay))
          .font(.headline)

        Spacer()

        Text(L10n.format("mediaPlan.fileCount", plan.items.count))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
          ForEach(plan.items) { item in
            HStack(spacing: 10) {
              Text(item.durationText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

              VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                  Text(item.sourceName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                  if let sizeText = item.sizeText {
                    Text(sizeText)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }

                Text(item.outputDisplayPath)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)

                MediaMetadataRows(item: item)
              }

              Spacer(minLength: 8)

              if let onOpen {
                Button {
                  onOpen(item)
                } label: {
                  if openingItemID == item.id {
                    ProgressView()
                      .controlSize(.small)
                      .frame(width: 18, height: 18)
                  } else {
                    Image(systemName: "play.circle")
                      .font(.body)
                  }
                }
                .buttonStyle(.borderless)
                .disabled(openingItemID != nil)
                .help(L10n.string("button.openMedia.help"))
              } else {
                Image(systemName: "arrow.right.circle")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
            }
            .padding(.horizontal, 10)
            .frame(height: Self.rowHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
            )
          }
        }
      }
      .frame(height: Self.visibleRowsHeight(itemCount: plan.items.count))
    }
  }

}

private struct MediaMetadataRows: View {
  let item: MediaPlanItem

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      metadataRow(title: L10n.string("mediaPlan.videoLabel"), values: values(from: item.videoText))
      metadataRow(title: L10n.string("mediaPlan.audioLabel"), values: values(from: item.audioText))
      metadataRow(title: L10n.string("mediaPlan.subtitlesLabel"), values: values(from: item.subtitlesText))
    }
    .padding(.top, 2)
  }

  @ViewBuilder
  private func metadataRow(title: String, values: [String]) -> some View {
    if !values.isEmpty {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 54, alignment: .leading)

        Text(values.joined(separator: "  |  "))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }

  private func values(from text: String?) -> [String] {
    guard let text, !text.trimmed.isEmpty else {
      return []
    }

    return text
      .components(separatedBy: ";")
      .map { $0.trimmed }
      .filter { !$0.isEmpty }
  }
}

private struct SummaryRows: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
      row(L10n.string("summary.input"), model.options.inputPath)
      row(L10n.string("summary.output"), model.options.outputDirectory)
      row(
        L10n.string("summary.mediaName"),
        model.options.mediaName.trimmed.isEmpty ? L10n.string("summary.autoDerived") : model.options.mediaName
      )
      row(L10n.string("summary.type"), model.mediaPlan.mediaTypeDisplay)
      row(L10n.string("summary.common"), commonText)
      row(L10n.string("summary.advanced"), advancedText)
    }
  }

  private var commonText: String {
    [
      model.options.dryRun ? L10n.string("option.dryRun") : nil,
      model.options.overwrite ? L10n.string("option.overwrite") : nil
    ]
    .compactMap { $0 }
    .joined(separator: L10n.string("list.separator"))
    .ifEmpty(L10n.string("summary.default"))
  }

  private var advancedText: String {
    [
      "S\(String(format: "%02d", model.options.season))",
      L10n.format("summary.episodeStart", String(format: "%02d", model.options.episodeStart)),
      L10n.format("summary.jobs", model.options.jobs),
      L10n.format("summary.minDuration", model.options.minDuration),
      model.options.noMediaDir ? L10n.string("option.noMediaDir") : nil,
      model.options.noSeasonDir ? L10n.string("option.noSeasonDir") : nil,
      model.options.useOriginalMediaContainer ? L10n.string("option.originalContainer") : nil
    ]
    .compactMap { $0 }
    .joined(separator: L10n.string("list.separator"))
  }

  @ViewBuilder
  private func row(_ title: String, _ value: String) -> some View {
    GridRow {
      Text(title)
        .foregroundStyle(.secondary)

      Text(value)
        .lineLimit(2)
        .textSelection(.enabled)
    }
  }
}

private struct DescribedToggle: View {
  let title: String
  let description: String
  @Binding var isOn: Bool
  let isDisabled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Toggle(title, isOn: $isOn)
        .disabled(isDisabled)

      Text(description)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 20)
    }
  }
}

private struct ParameterStepper: View {
  let title: String
  @Binding var value: Int
  let range: ClosedRange<Int>
  let step: Int
  var suffix = ""
  let isDisabled: Bool

  var body: some View {
    Stepper(value: $value, in: range, step: step) {
      HStack {
        Text(title)
        Spacer()
        Text(displayValue)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .disabled(isDisabled)
  }

  private var displayValue: String {
    suffix.isEmpty ? String(value) : "\(value) \(suffix)"
  }
}

private extension String {
  func ifEmpty(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
