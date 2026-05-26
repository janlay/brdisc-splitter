import AppKit
import SwiftUI

struct ContentView: View {
  private enum Layout {
    static let introWidth: CGFloat = 520
    static let controlsWidth: CGFloat = 620
    static let logWidth: CGFloat = 480
    static let introHeight: CGFloat = 330
    static let minimumHeight: CGFloat = 260
    static let inputBaseHeight: CGFloat = 260
    static let optionsBaseHeight: CGFloat = 365
    static let optionsAdvancedHeight: CGFloat = 330
    static let outputDirectoryShortcutHeight: CGFloat = 28
    static let optionsStatusHeight: CGFloat = 36
    static let confirmHeight: CGFloat = 570
    static let runningHeight: CGFloat = 620
    static let completeHeight: CGFloat = 380
    static let introTitleIconWidth: CGFloat = 28
    static let introTitleSpacing: CGFloat = 6
  }

  private enum WizardStep: Equatable {
    case intro
    case input
    case options
    case confirm
    case complete

    var title: String {
      switch self {
      case .intro:
        return L10n.string("wizard.step.intro.title")
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
    width: Layout.introWidth,
    height: Layout.introHeight
  )

  static let minimumContentSize = CGSize(
    width: Layout.introWidth,
    height: Layout.minimumHeight
  )

  @ObservedObject var model: AppModel
  @State private var step: WizardStep = .intro
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
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        breadcrumbProgress

        Text(model.statusText)
          .font(.caption)
          .foregroundStyle(statusStyle)
          .lineLimit(2)
      }

      Spacer()

      Button {
        setLogVisibility(!isLogVisible)
      } label: {
        Image(systemName: "sidebar.right")
      }
      .help(isLogVisible ? L10n.string("log.hide") : L10n.string("log.show"))
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var breadcrumbProgress: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      ForEach(Array(breadcrumbSteps.enumerated()), id: \.offset) { index, breadcrumbStep in
        Text(breadcrumbStep.title)
          .font(index == currentBreadcrumbIndex ? .title3 : .callout)
          .fontWeight(index == currentBreadcrumbIndex ? .semibold : .regular)
          .foregroundStyle(breadcrumbStyle(for: index))
          .lineLimit(1)

        if index < breadcrumbSteps.count - 1 {
          Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
    }
  }

  private var breadcrumbSteps: [WizardStep] {
    [.intro, .input, .options, .confirm, .complete]
  }

  private var currentBreadcrumbIndex: Int {
    breadcrumbSteps.firstIndex(of: step) ?? breadcrumbSteps.count - 1
  }

  private func breadcrumbStyle(for index: Int) -> some ShapeStyle {
    if index < currentBreadcrumbIndex {
      return AnyShapeStyle(Color.accentColor)
    }

    if index == currentBreadcrumbIndex {
      return AnyShapeStyle(.primary)
    }

    return AnyShapeStyle(.secondary)
  }

  @ViewBuilder
  private var stepBody: some View {
    switch step {
    case .intro:
      introStep
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

  private var introStep: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 14) {
        Grid(alignment: .leading, horizontalSpacing: Layout.introTitleSpacing, verticalSpacing: 3) {
          GridRow(alignment: .firstTextBaseline) {
            Image(systemName: "opticaldiscdrive")
              .font(.title2)
              .fontWeight(.semibold)
              .frame(width: Layout.introTitleIconWidth, alignment: .leading)

            Text("BRDisc Splitter")
              .font(.title2)
              .fontWeight(.semibold)
          }

          GridRow {
            Color.clear
              .frame(width: Layout.introTitleIconWidth, height: 0)

            Text(AppVersion.displayText)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text(L10n.string("intro.description"))
          .fixedSize(horizontal: false, vertical: true)

        Text(L10n.string("intro.requirement"))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: 280, alignment: .leading)

      Spacer(minLength: 0)

      ExtractionIllustration()
        .frame(width: 170, height: 160)
    }
  }

  private var inputStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      DropTargetView(
        inputPath: model.options.inputPath,
        isDisabled: model.isBusy,
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
        Label(message, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
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
        Label(L10n.format("error.extractionFailed", exitCode), systemImage: "xmark.octagon")
          .foregroundStyle(.red)
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
      case .intro:
        LanguagePicker(language: $model.language)

        Spacer()

        Button(L10n.string("button.continue")) {
          setStep(.input)
        }
        .buttonStyle(.borderedProminent)

      case .input:
        Button(L10n.string("button.back")) {
          setStep(.intro)
        }
        .disabled(model.isBusy)

        Spacer()

        Button(L10n.string("button.next")) {
          setStep(.options)
        }
        .buttonStyle(.borderedProminent)
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
        .disabled(!model.canStart)

      case .complete:
        Button(L10n.string("button.openInFinder")) {
          model.openOutputInFinder()
        }

        Spacer()

        Button(L10n.string("button.quit")) {
          model.quit()
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }

  private var preferredPaneWidth: CGFloat {
    step == .intro ? Layout.introWidth : Layout.controlsWidth
  }

  private var preferredContentWidth: CGFloat {
    preferredPaneWidth + (isLogVisible ? Layout.logWidth : 0)
  }

  private var preferredContentHeight: CGFloat {
    switch step {
    case .intro:
      return Layout.introHeight
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
      height += 40
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

  private var statusStyle: some ShapeStyle {
    if model.isRunning || model.isScanning {
      return AnyShapeStyle(.primary)
    }

    if let exitCode = model.lastExitCode, exitCode != 0 {
      return AnyShapeStyle(.red)
    }

    if model.validationMessage != nil || model.scanMessage != nil {
      return AnyShapeStyle(.secondary)
    }

    return AnyShapeStyle(.green)
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

private struct LanguagePicker: View {
  @Binding var language: AppLanguage

  var body: some View {
    HStack(spacing: 8) {
      Text(L10n.string("language.label"))
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker(L10n.string("language.label"), selection: $language) {
        ForEach(AppLanguage.allCases) { language in
          Text(language.displayName)
            .tag(language)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(width: 130)
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

private struct ExtractionIllustration: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack(alignment: .center) {
      HStack(spacing: 15) {
        disc

        Image(systemName: "arrow.right")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.accentColor)

        files
      }
    }
    .accessibilityHidden(true)
  }

  private var disc: some View {
    ZStack {
      Circle()
        .fill(
          AngularGradient(
            colors: discColors,
            center: .center,
            angle: .degrees(-25)
          )
        )
        .overlay(
          Circle()
            .fill(
              RadialGradient(
                colors: [
                  Color.white.opacity(colorScheme == .dark ? 0.34 : 0.56),
                  Color.clear
                ],
                center: UnitPoint(x: 0.28, y: 0.24),
                startRadius: 2,
                endRadius: 46
              )
            )
        )
        .overlay(Circle().stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.32), lineWidth: 1.2))

      Circle()
        .stroke(Color.white.opacity(colorScheme == .dark ? 0.28 : 0.5), lineWidth: 0.8)
        .frame(width: 42, height: 42)

      Circle()
        .fill(discCenterFill)
        .frame(width: 16, height: 16)
        .overlay(Circle().stroke(Color.secondary.opacity(colorScheme == .dark ? 0.52 : 0.35), lineWidth: 1))
    }
    .frame(width: 70, height: 70)
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.08), radius: 3, x: 0, y: 2)
  }

  private var files: some View {
    ZStack(alignment: .bottomTrailing) {
      file(offset: CGSize(width: -10, height: -12), opacity: 0.5)
      file(offset: CGSize(width: -5, height: -6), opacity: 0.72)
      file(offset: .zero, opacity: 1)
    }
    .frame(width: 48, height: 70)
  }

  private func file(offset: CGSize, opacity: Double) -> some View {
    RoundedRectangle(cornerRadius: 5)
      .fill(fileFill)
      .overlay(
        VStack(alignment: .leading, spacing: 5) {
          Capsule()
            .fill(Color.accentColor.opacity(0.75))
            .frame(width: 22, height: 4)

          Capsule()
            .fill(fileLineFill.opacity(0.52))
            .frame(width: 30, height: 4)

          Capsule()
            .fill(fileLineFill.opacity(0.38))
            .frame(width: 24, height: 4)

          Spacer(minLength: 0)
        }
        .padding(8),
        alignment: .topLeading
      )
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(fileStroke, lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 3, x: 0, y: 2)
      .frame(width: 42, height: 58)
      .opacity(opacity)
      .offset(offset)
  }

  private var discColors: [Color] {
    if colorScheme == .dark {
      return [
        Color(red: 0.38, green: 0.68, blue: 0.95),
        Color(red: 0.86, green: 0.94, blue: 1.0),
        Color(red: 0.24, green: 0.38, blue: 0.68),
        Color(red: 0.5, green: 0.78, blue: 1.0)
      ]
    }

    return [
      Color(red: 0.56, green: 0.78, blue: 1.0),
      Color.white,
      Color(red: 0.45, green: 0.64, blue: 0.88),
      Color(red: 0.72, green: 0.88, blue: 1.0)
    ]
  }

  private var discCenterFill: Color {
    colorScheme == .dark ? Color(red: 0.18, green: 0.2, blue: 0.24) : Color(nsColor: .controlBackgroundColor)
  }

  private var fileFill: Color {
    colorScheme == .dark ? Color(red: 0.9, green: 0.92, blue: 0.96) : Color(nsColor: .textBackgroundColor)
  }

  private var fileLineFill: Color {
    colorScheme == .dark ? Color(red: 0.22, green: 0.26, blue: 0.32) : Color.secondary
  }

  private var fileStroke: Color {
    colorScheme == .dark ? Color.white.opacity(0.22) : Color.secondary.opacity(0.22)
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
  private static let rowHeight: CGFloat = 38
  private static let rowSpacing: CGFloat = 8
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
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(item.durationText)
                .monospacedDigit()
                .foregroundStyle(.secondary)

              Text(item.sourceName)
                .lineLimit(1)
            }

            Text(item.outputDisplayPath)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .frame(height: Self.rowHeight, alignment: .leading)
          .frame(maxWidth: .infinity, alignment: .leading)
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
