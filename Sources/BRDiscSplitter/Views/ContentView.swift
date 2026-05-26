import AppKit
import SwiftUI

struct ContentView: View {
  private enum Layout {
    static let controlsWidth: CGFloat = 680
    static let logWidth: CGFloat = 520
    static let minimumHeight: CGFloat = 360
    static let inputBaseHeight: CGFloat = 390
    static let optionsBaseHeight: CGFloat = 430
    static let optionsAdvancedHeight: CGFloat = 330
    static let outputDirectoryShortcutHeight: CGFloat = 28
    static let optionsStatusHeight: CGFloat = 36
    static let confirmHeight: CGFloat = 610
    static let runningHeight: CGFloat = 650
    static let completeHeight: CGFloat = 430
  }

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

  static let initialContentSize = CGSize(
    width: Layout.controlsWidth,
    height: Layout.inputBaseHeight
  )

  static let minimumContentSize = CGSize(
    width: Layout.controlsWidth,
    height: Layout.minimumHeight
  )

  @ObservedObject var model: AppModel
  @State private var step: WizardStep = .input
  @State private var isAdvancedExpanded = false
  @State private var isLogVisible = false
  @State private var window: NSWindow?
  @State private var pendingAdvanceAfterScan = false

  var body: some View {
    content
      .frame(width: preferredContentWidth)
      .frame(height: preferredContentHeight)
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
        resizeWindow()
      }
      .onChange(of: model.isScanning) { isScanning in
        handleScanStateChange(isScanning: isScanning)
      }
      .onChange(of: model.isRunning) { isRunning in
        handleRunStateChange(isRunning: isRunning)
      }
      .onChange(of: model.mediaPlan.items.count) { _ in
        resizeWindow()
      }
  }

  private var content: some View {
    Group {
      if isLogVisible {
        HSplitView {
          wizardPane
            .frame(width: preferredPaneWidth, height: preferredContentHeight)
            .layoutPriority(1)

          LogView(model: model)
            .frame(width: Layout.logWidth, height: preferredContentHeight)
        }
      } else {
        wizardPane
          .frame(width: preferredPaneWidth, height: preferredContentHeight)
      }
    }
  }

  private var wizardPane: some View {
    VStack(spacing: 0) {
      header

      Divider()

      stepBody
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        MediaPlanListView(plan: model.mediaPlan)
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

      MediaPlanListView(plan: model.mediaPlan, maxVisibleRows: 4)

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

  private var preferredContentHeight: CGFloat {
    switch step {
    case .input:
      return inputContentHeight
    case .options:
      return optionsContentHeight
    case .confirm:
      return model.isRunning ? Layout.runningHeight : Layout.confirmHeight
    case .complete:
      return Layout.completeHeight
    }
  }

  private var inputContentHeight: CGFloat {
    var height = Layout.inputBaseHeight

    if model.isScanning {
      height += 34
    }

    if model.scanMessage != nil, !model.isScanning {
      height += 72
    }

    if model.hasMediaPlan {
      height += 16 + MediaPlanListView.estimatedHeight(itemCount: model.mediaPlan.items.count)
    }

    return height
  }

  private var optionsContentHeight: CGFloat {
    var height = Layout.optionsBaseHeight

    if model.inputISOParentDirectory != nil {
      height += Layout.outputDirectoryShortcutHeight
    }

    if isAdvancedExpanded {
      height += Layout.optionsAdvancedHeight
    }

    if model.isScanning || (model.scanMessage != nil && model.needsPlanRefresh) {
      height += Layout.optionsStatusHeight
    }

    return height
  }

  private var advancedExpansion: Binding<Bool> {
    Binding(
      get: { isAdvancedExpanded },
      set: { setAdvancedVisibility($0) }
    )
  }

  private var statusTone: StatusBadge.Tone {
    if model.isRunning || model.isScanning {
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
    resizeWindow()
  }

  private func startExtraction() {
    model.start()
    resizeWindow()
  }

  private func handleScanStateChange(isScanning: Bool) {
    if !isScanning, pendingAdvanceAfterScan {
      pendingAdvanceAfterScan = false

      if model.hasMediaPlan {
        setStep(.confirm)
      }
    }

    resizeWindow()
  }

  private func handleRunStateChange(isRunning: Bool) {
    if !isRunning, model.lastExitCode == 0, model.completionSummary != nil {
      setStep(.complete)
      return
    }

    resizeWindow()
  }

  private func setStep(_ newStep: WizardStep) {
    guard step != newStep else {
      return
    }

    withoutAnimation {
      step = newStep
    }
    resizeWindow()
  }

  private func setLogVisibility(_ visible: Bool) {
    guard visible != isLogVisible else {
      return
    }

    withoutAnimation {
      isLogVisible = visible
    }
    resizeWindow()
  }

  private func setAdvancedVisibility(_ visible: Bool) {
    guard visible != isAdvancedExpanded else {
      return
    }

    withoutAnimation {
      isAdvancedExpanded = visible
    }
    resizeWindow()
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
  }

  private func resizeWindow() {
    guard let window else {
      return
    }

    let targetContentSize = CGSize(
      width: preferredContentWidth,
      height: preferredContentHeight
    )
    let targetFrameSize = window.frameRect(
      forContentRect: CGRect(origin: .zero, size: targetContentSize)
    ).size

    DispatchQueue.main.async {
      window.minSize = targetFrameSize

      var frame = window.frame
      let top = frame.maxY
      frame.size.width = targetFrameSize.width
      frame.size.height = targetFrameSize.height
      frame.origin.y = top - frame.height

      window.setFrame(frame, display: true, animate: false)
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
  var maxVisibleRows = 6

  private static let headerHeight: CGFloat = 24
  private static let headerSpacing: CGFloat = 8
  private static let rowHeight: CGFloat = 48
  private static let rowSpacing: CGFloat = 6
  private static let remainingHeight: CGFloat = 18

  static func estimatedHeight(itemCount: Int, maxVisibleRows: Int = 6) -> CGFloat {
    let visibleRows = min(itemCount, maxVisibleRows)
    guard visibleRows > 0 else {
      return headerHeight
    }

    var height = headerHeight + headerSpacing + rowsHeight(visibleRows)

    if itemCount > visibleRows {
      height += rowSpacing + remainingHeight
    }

    return height
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

      VStack(alignment: .leading, spacing: Self.rowSpacing) {
        ForEach(Array(plan.items.prefix(maxVisibleRows))) { item in
          HStack(spacing: 10) {
            Text(item.durationText)
              .font(.caption)
              .monospacedDigit()
              .foregroundStyle(.secondary)
              .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
              Text(item.sourceName)
                .font(.callout.weight(.medium))
                .lineLimit(1)

              Text(item.outputDisplayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.right.circle")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 10)
          .frame(height: Self.rowHeight, alignment: .leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(nsColor: .controlBackgroundColor))
          )
        }

        if plan.items.count > maxVisibleRows {
          Text(L10n.format("mediaPlan.remainingCount", plan.items.count - maxVisibleRows))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
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
