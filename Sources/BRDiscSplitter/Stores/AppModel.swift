import AppKit
import Foundation

struct MediaPlan: Equatable {
  var mediaType = ""
  var items: [MediaPlanItem] = []

  var mediaTypeDisplay: String {
    switch mediaType {
    case "movie":
      return L10n.string("media.type.movie")
    case "series":
      return L10n.string("media.type.series")
    default:
      return mediaType.isEmpty ? L10n.string("media.type.unknown") : mediaType
    }
  }
}

struct MediaPlanItem: Identifiable, Equatable {
  var index: Int
  let durationText: String
  let sourceName: String
  let outputDisplayPath: String
  let outputPath: String
  var sourcePath: String?
  var sizeText: String?
  var videoText: String?
  var audioText: String?
  var subtitlesText: String?

  var id: String {
    "\(index)|\(sourceName)|\(outputPath)"
  }
}

struct ExtractionProgress: Equatable {
  var completed = 0
  var total = 0

  var fraction: Double {
    guard total > 0 else {
      return 0
    }

    return Double(completed) / Double(total)
  }

  var displayText: String {
    total > 0 ? "\(completed)/\(total)" : L10n.string("progress.waiting")
  }
}

struct ExtractionSummary: Equatable {
  let fileCount: Int
  let plannedCount: Int
  let totalBytes: Int64
  let outputDirectory: String
  let isDryRun: Bool

  var formattedBytes: String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: totalBytes)
  }
}

enum MediaPlanParser {
  static func parse(_ output: String, outputDirectory: String) -> MediaPlan {
    var plan = MediaPlan()
    var isReadingTasks = false

    for rawLine in normalizedLines(output) {
      let line = rawLine.trimmed
      guard !line.isEmpty else {
        continue
      }

      if line.hasPrefix("Detected media type:") {
        parseMediaType(line, into: &plan)
        continue
      }

      if line == "Planned extraction:" {
        isReadingTasks = true
        continue
      }

      if isReadingTasks, let item = parseItem(
        line,
        outputDirectory: outputDirectory,
        fallbackIndex: plan.items.count + 1
      ) {
        plan.items.append(item)
        continue
      }

      if isReadingTasks, !plan.items.isEmpty {
        applyDetail(line, to: &plan.items[plan.items.count - 1])
      }
    }

    return plan
  }

  private static func normalizedLines(_ output: String) -> [String] {
    output
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
  }

  private static func parseMediaType(_ line: String, into plan: inout MediaPlan) {
    let prefix = "Detected media type:"
    let value = String(line.dropFirst(prefix.count)).trimmed

    if let openParen = value.firstIndex(of: "(") {
      plan.mediaType = String(value[..<openParen]).trimmed
    } else {
      plan.mediaType = value
    }
  }

  private static func parseItem(
    _ line: String,
    outputDirectory: String,
    fallbackIndex: Int
  ) -> MediaPlanItem? {
    guard line.count > 10 else {
      return nil
    }

    let duration = String(line.prefix(8))
    guard isDuration(duration) else {
      return nil
    }

    let rest = String(line.dropFirst(8)).trimmed
    let parts = rest.components(separatedBy: " -> ")
    guard parts.count >= 2 else {
      return nil
    }

    let sourceName = parts[0].trimmed
    let outputDisplayPath = parts.dropFirst().joined(separator: " -> ").trimmed
    let outputPath: String

    if outputDisplayPath.hasPrefix("/") {
      outputPath = outputDisplayPath
    } else {
      outputPath = URL(fileURLWithPath: outputDirectory)
        .appendingPathComponent(outputDisplayPath)
        .standardizedFileURL
        .path
    }

    return MediaPlanItem(
      index: fallbackIndex,
      durationText: duration,
      sourceName: sourceName,
      outputDisplayPath: outputDisplayPath,
      outputPath: outputPath,
      sourcePath: nil,
      sizeText: nil,
      videoText: nil,
      audioText: nil,
      subtitlesText: nil
    )
  }

  private static func applyDetail(_ line: String, to item: inout MediaPlanItem) {
    let detail = line.trimmed

    if let value = value(in: detail, for: "index"), let index = Int(value) {
      item.index = index
    } else if let value = value(in: detail, for: "source") {
      item.sourcePath = value
    } else if let value = value(in: detail, for: "size") {
      item.sizeText = stripByteSuffix(from: value)
    } else if let value = value(in: detail, for: "video") {
      item.videoText = value
    } else if let value = value(in: detail, for: "audio") {
      item.audioText = value
    } else if let value = value(in: detail, for: "subtitles") {
      item.subtitlesText = value
    }
  }

  private static func value(in line: String, for key: String) -> String? {
    let prefix = "\(key):"
    guard line.hasPrefix(prefix) else {
      return nil
    }

    return String(line.dropFirst(prefix.count)).trimmed
  }

  private static func stripByteSuffix(from sizeText: String) -> String {
    guard let range = sizeText.range(of: " (", options: .backwards) else {
      return sizeText
    }

    return String(sizeText[..<range.lowerBound])
  }

  private static func isDuration(_ value: String) -> Bool {
    let parts = value.split(separator: ":")
    guard parts.count == 3 else {
      return false
    }

    return parts.allSatisfy { Int($0) != nil }
  }
}

@MainActor
final class AppModel: ObservableObject {
  @Published var options = SplitterOptions()
  @Published var language = L10n.language {
    didSet {
      guard language != oldValue else {
        return
      }

      L10n.setLanguage(language)
      NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
      refreshStatus()
    }
  }
  @Published var logText = ""
  @Published var statusText = L10n.string("status.ready")
  @Published var isRunning = false
  @Published var isScanning = false
  @Published var lastExitCode: Int32?
  @Published var scanMessage: String?
  @Published var mediaPlan = MediaPlan()
  @Published var progress = ExtractionProgress()
  @Published var completionSummary: ExtractionSummary?
  @Published var openingItemID: String?

  private let runner = SplitterRunner()
  private let scanner = SplitterRunner()
  private let opener = SplitterRunner()
  private var didBootstrap = false
  private var scanBuffer = ""
  private var lastScanOptions: SplitterOptions?
  private var runningOptions: SplitterOptions?

  private var planChangedMessage: String {
    L10n.string("status.planChangedRescan")
  }

  var validationMessage: String? {
    options.validationMessage()
  }

  var canStart: Bool {
    validationMessage == nil && !isRunning && !isScanning && hasMediaPlan && !needsPlanRefresh
  }

  var isBusy: Bool {
    isRunning || isScanning
  }

  var isOpening: Bool {
    openingItemID != nil
  }

  var hasMediaPlan: Bool {
    !mediaPlan.items.isEmpty && scanMessage == nil
  }

  var needsPlanRefresh: Bool {
    guard let lastScanOptions else {
      return !options.inputPath.trimmed.isEmpty
    }

    return !options.planMatches(lastScanOptions)
  }

  var inputISOParentDirectory: String? {
    let inputPath = options.inputPath.trimmed
    guard inputPath.lowercased().hasSuffix(".iso") else {
      return nil
    }

    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory),
      !isDirectory.boolValue
    else {
      return nil
    }

    return URL(fileURLWithPath: inputPath)
      .deletingLastPathComponent()
      .standardizedFileURL
      .path
  }

  func bootstrap() {
    guard !didBootstrap else {
      return
    }

    didBootstrap = true

    if let message = validationMessage {
      statusText = message
    }
  }

  func chooseInput() {
    guard !isBusy, let path = PanelPresenter.chooseInput() else {
      return
    }

    setInput(path)
  }

  func chooseOutputDirectory() {
    guard !isBusy, let path = PanelPresenter.chooseOutputDirectory() else {
      return
    }

    options.outputDirectory = path
    invalidatePlan()
    refreshStatus()
  }

  func useInputISOParentDirectoryForOutput() {
    guard !isBusy, let directory = inputISOParentDirectory else {
      return
    }

    guard options.outputDirectory != directory else {
      return
    }

    options.outputDirectory = directory
    invalidatePlan()
    refreshStatus()
  }

  func chooseCLIPath() {
    guard !isBusy, let path = PanelPresenter.chooseCLIPath() else {
      return
    }

    options.cliPath = path
    invalidatePlan()
    refreshStatus()
  }

  func setDroppedInput(path: String) {
    guard !isBusy else {
      return
    }

    setInput(path)
  }

  func setInput(_ path: String) {
    guard !isBusy else {
      return
    }

    options.inputPath = path
    mediaPlan = MediaPlan()
    lastScanOptions = nil
    scanMessage = nil
    completionSummary = nil
    refreshStatus()
    scanInput()
  }

  func scanInput() {
    guard !isRunning, !isScanning else {
      return
    }

    clampNumericOptions()

    if let message = options.validationMessage() {
      mediaPlan = MediaPlan()
      lastScanOptions = nil
      scanMessage = message
      statusText = message
      return
    }

    let scanOptions = options
    let scriptPath = scanOptions.cliPath
    let workingDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()

    scanBuffer = ""
    scanMessage = nil
    mediaPlan = MediaPlan()
    isScanning = true
    lastExitCode = nil
    completionSummary = nil
    statusText = L10n.string("status.scanningMedia")

    appendLog("> \(scanOptions.commandPreview(forceDryRun: true))\n\n")

    do {
      try scanner.run(
        scriptPath: scriptPath,
        arguments: scanOptions.commandArguments(forceDryRun: true),
        workingDirectory: workingDirectory,
        onOutput: { [weak self] text in
          Task { @MainActor in
            self?.appendScanOutput(text)
          }
        },
        onCompletion: { [weak self] exitCode in
          Task { @MainActor in
            self?.finishScan(exitCode: exitCode, options: scanOptions)
          }
        }
      )
    } catch {
      isScanning = false
      scanMessage = error.localizedDescription
      statusText = error.localizedDescription
      appendLog("\n\(error.localizedDescription)\n")
    }
  }

  func start() {
    clampNumericOptions()

    if let message = validationMessage {
      statusText = message
      return
    }

    guard hasMediaPlan, !needsPlanRefresh else {
      scanMessage = L10n.string("status.planChangedRescanShort")
      statusText = scanMessage ?? L10n.string("status.needRescan")
      return
    }

    let arguments = options.commandArguments
    let scriptPath = options.cliPath
    let workingDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()

    logText = "> \(options.commandPreview)\n\n"
    progress = ExtractionProgress(completed: 0, total: mediaPlan.items.count)
    completionSummary = nil
    statusText = options.dryRun ? L10n.string("status.previewing") : L10n.string("status.extracting")
    isRunning = true
    lastExitCode = nil
    runningOptions = options

    do {
      try runner.run(
        scriptPath: scriptPath,
        arguments: arguments,
        workingDirectory: workingDirectory,
        onOutput: { [weak self] text in
          Task { @MainActor in
            self?.appendLog(text)
          }
        },
        onCompletion: { [weak self] exitCode in
          Task { @MainActor in
            self?.finish(exitCode: exitCode)
          }
        }
      )
    } catch {
      isRunning = false
      statusText = error.localizedDescription
      appendLog("\n\(error.localizedDescription)\n")
    }
  }

  func cancel() {
    guard isRunning else {
      return
    }

    statusText = L10n.string("status.canceling")
    appendLog("\n> cancel\n")
    runner.cancel()
  }

  func clearLog() {
    guard !isBusy, !isOpening else {
      return
    }

    logText = ""
    lastExitCode = nil
    refreshStatus()
  }

  func refreshValidationStatus() {
    guard !isBusy else {
      return
    }

    if let lastScanOptions {
      if options.planMatches(lastScanOptions) {
        if scanMessage == planChangedMessage {
          scanMessage = nil
        }
      } else {
        scanMessage = planChangedMessage
      }
    }

    refreshStatus()
  }

  func copyLog() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(logText, forType: .string)
  }

  func openOutputInFinder() {
    let outputDirectory = completionSummary?.outputDirectory ?? options.outputDirectory
    NSWorkspace.shared.open(URL(fileURLWithPath: outputDirectory))
  }

  func openMediaItem(_ item: MediaPlanItem) {
    guard !isRunning, !isScanning, openingItemID == nil else {
      return
    }

    guard let openOptions = lastScanOptions, !needsPlanRefresh else {
      scanMessage = L10n.string("status.planChangedRescanShort")
      statusText = scanMessage ?? L10n.string("status.needRescan")
      return
    }

    let arguments = openOptions.commandArguments(forceDryRun: false) + ["--open", String(item.index)]
    let scriptPath = openOptions.cliPath
    let workingDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
    let preview = (["/bin/bash", scriptPath] + arguments)
      .map { $0.shellQuoted }
      .joined(separator: " ")
    let itemID = item.id

    openingItemID = itemID
    statusText = L10n.format("status.openingMedia", item.sourceName)
    appendLog("> \(preview)\n\n")

    do {
      try opener.run(
        scriptPath: scriptPath,
        arguments: arguments,
        workingDirectory: workingDirectory,
        onOutput: { [weak self] text in
          Task { @MainActor in
            self?.appendLog(text)
          }
        },
        onCompletion: { [weak self] exitCode in
          Task { @MainActor in
            self?.finishOpen(exitCode: exitCode, itemID: itemID)
          }
        }
      )
    } catch {
      openingItemID = nil
      statusText = error.localizedDescription
      appendLog("\n\(error.localizedDescription)\n")
    }
  }

  func quit() {
    NSApp.terminate(nil)
  }

  func resetForNewTask() {
    guard !isBusy, !isOpening else {
      return
    }

    var nextOptions = options
    nextOptions.inputPath = ""
    nextOptions.mediaName = ""

    options = nextOptions
    logText = ""
    lastExitCode = nil
    scanMessage = nil
    mediaPlan = MediaPlan()
    progress = ExtractionProgress()
    completionSummary = nil
    openingItemID = nil
    lastScanOptions = nil
    runningOptions = nil
    refreshStatus()
  }

  private func finishScan(exitCode: Int32, options scanOptions: SplitterOptions) {
    isScanning = false

    if exitCode == 0 {
      let plan = MediaPlanParser.parse(scanBuffer, outputDirectory: scanOptions.outputDirectory)

      if plan.items.isEmpty {
        scanMessage = L10n.string("status.scanEmpty")
        statusText = scanMessage ?? L10n.string("status.scanFailed")
      } else {
        mediaPlan = plan
        lastScanOptions = scanOptions
        scanMessage = nil
        statusText = L10n.format("status.scanRecognized", plan.items.count)
      }

      appendLog("\n> scan finished: 0\n")
    } else {
      mediaPlan = MediaPlan()
      lastScanOptions = nil
      scanMessage = L10n.format("status.scanFailedWithCode", exitCode)
      statusText = scanMessage ?? L10n.string("status.scanFailed")
      appendLog("\n> scan failed: \(exitCode)\n")
    }

    scanBuffer = ""
  }

  private func finish(exitCode: Int32) {
    lastExitCode = exitCode

    if exitCode == 0 {
      if progress.total > 0 {
        progress.completed = progress.total
      }

      completionSummary = makeSummary(options: runningOptions ?? options)
      statusText = L10n.string("status.finished")
      appendLog("\n> finished: 0\n")
    } else {
      statusText = L10n.format("status.failedWithCode", exitCode)
      appendLog("\n> failed: \(exitCode)\n")
    }

    runningOptions = nil
    isRunning = false
  }

  private func finishOpen(exitCode: Int32, itemID: String) {
    if openingItemID == itemID {
      openingItemID = nil
    }

    if exitCode == 0 {
      appendLog("\n> open finished: 0\n")
      refreshStatus()
    } else {
      statusText = L10n.format("status.openFailedWithCode", exitCode)
      appendLog("\n> open failed: \(exitCode)\n")
    }
  }

  private func makeSummary(options: SplitterOptions) -> ExtractionSummary {
    guard !options.dryRun else {
      return ExtractionSummary(
        fileCount: 0,
        plannedCount: mediaPlan.items.count,
        totalBytes: 0,
        outputDirectory: options.outputDirectory,
        isDryRun: true
      )
    }

    var fileCount = 0
    var totalBytes: Int64 = 0

    for item in mediaPlan.items {
      guard FileManager.default.fileExists(atPath: item.outputPath),
        let attributes = try? FileManager.default.attributesOfItem(atPath: item.outputPath),
        let size = attributes[.size] as? NSNumber
      else {
        continue
      }

      fileCount += 1
      totalBytes += size.int64Value
    }

    return ExtractionSummary(
      fileCount: fileCount,
      plannedCount: mediaPlan.items.count,
      totalBytes: totalBytes,
      outputDirectory: options.outputDirectory,
      isDryRun: false
    )
  }

  private func appendScanOutput(_ text: String) {
    scanBuffer += text
    appendLog(text)
  }

  private func appendLog(_ text: String) {
    let normalized = text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    logText += normalized
    updateProgress(from: normalized)
  }

  private func updateProgress(from text: String) {
    for line in text.components(separatedBy: "\n") {
      for token in line.split(separator: " ") {
        let parts = token.split(separator: "/")
        guard parts.count == 2,
          let completed = Int(parts[0]),
          let total = Int(parts[1]),
          total > 0
        else {
          continue
        }

        progress = ExtractionProgress(completed: completed, total: total)
      }
    }
  }

  private func refreshStatus() {
    if let message = validationMessage {
      statusText = message
    } else if let scanMessage {
      statusText = scanMessage
    } else {
      statusText = L10n.string("status.ready")
    }
  }

  private func invalidatePlan() {
    guard lastScanOptions != nil else {
      return
    }

    scanMessage = planChangedMessage
  }

  private func clampNumericOptions() {
    options.season = max(1, options.season)
    options.episodeStart = max(1, options.episodeStart)
    options.jobs = max(1, options.jobs)
    options.minDuration = max(1, options.minDuration)
  }
}
