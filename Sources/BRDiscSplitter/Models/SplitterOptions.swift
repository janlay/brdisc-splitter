import Foundation

struct SplitterOptions: Equatable {
  var inputPath = ""
  var outputDirectory = PathDefaults.defaultOutputDirectory()
  var mediaName = ""
  var season = 1
  var episodeStart = 1
  var jobs = 1
  var dryRun = false

  var minDuration = 1200
  var noMediaDir = false
  var noSeasonDir = false
  var useOriginalMediaContainer = false
  var overwrite = false
  var cliPath = PathDefaults.defaultCLIPath()

  var commandArguments: [String] {
    commandArguments(forceDryRun: nil)
  }

  func commandArguments(forceDryRun: Bool?) -> [String] {
    var arguments = ["-i", inputPath]

    if !outputDirectory.trimmed.isEmpty {
      arguments += ["-o", outputDirectory]
    }

    if !mediaName.trimmed.isEmpty {
      arguments += ["--name", mediaName]
    }

    arguments += [
      "--season", String(season),
      "--episode-start", String(episodeStart),
      "--min-duration", String(minDuration),
      "--jobs", String(jobs)
    ]

    let shouldUseDryRun = forceDryRun ?? dryRun
    if shouldUseDryRun {
      arguments.append("--dry-run")
    }

    if noMediaDir {
      arguments.append("--no-media-dir")
    }

    if noSeasonDir {
      arguments.append("--no-season-dir")
    }

    if useOriginalMediaContainer {
      arguments.append("--use-original-media-container")
    }

    if overwrite {
      arguments.append("--overwrite")
    }

    return arguments
  }

  var commandPreview: String {
    commandPreview(forceDryRun: nil)
  }

  func commandPreview(forceDryRun: Bool?) -> String {
    (["/bin/bash", cliPath] + commandArguments(forceDryRun: forceDryRun))
      .map { $0.shellQuoted }
      .joined(separator: " ")
  }

  func validationMessage() -> String? {
    if let message = inputValidationMessage() {
      return message
    }

    guard season > 0 else {
      return L10n.string("validation.seasonPositive")
    }

    guard episodeStart > 0 else {
      return L10n.string("validation.episodeStartPositive")
    }

    guard jobs > 0 else {
      return L10n.string("validation.jobsPositive")
    }

    guard minDuration > 0 else {
      return L10n.string("validation.minDurationPositive")
    }

    guard !cliPath.trimmed.isEmpty else {
      return L10n.string("validation.cliPathRequired")
    }

    var cliIsDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: cliPath, isDirectory: &cliIsDirectory),
      !cliIsDirectory.boolValue
    else {
      return L10n.string("validation.cliNotFound")
    }

    return nil
  }

  func inputValidationMessage() -> String? {
    let fileManager = FileManager.default

    guard !inputPath.trimmed.isEmpty else {
      return L10n.string("validation.inputRequired")
    }

    var isDirectory = ObjCBool(false)
    guard fileManager.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
      return L10n.string("validation.inputMissing")
    }

    if isDirectory.boolValue {
      let url = URL(fileURLWithPath: inputPath)
      let hasStreamDirectory =
        fileManager.fileExists(atPath: url.appendingPathComponent("BDMV/STREAM").path) ||
        (url.lastPathComponent == "BDMV" &&
          fileManager.fileExists(atPath: url.appendingPathComponent("STREAM").path))

      guard hasStreamDirectory else {
        return L10n.string("validation.streamMissing")
      }
    } else if !inputPath.lowercased().hasSuffix(".iso") {
      return L10n.string("validation.inputInvalid")
    }

    return nil
  }

  func planMatches(_ other: SplitterOptions) -> Bool {
    inputPath == other.inputPath &&
      outputDirectory == other.outputDirectory &&
      mediaName == other.mediaName &&
      season == other.season &&
      episodeStart == other.episodeStart &&
      minDuration == other.minDuration &&
      noMediaDir == other.noMediaDir &&
      noSeasonDir == other.noSeasonDir &&
      useOriginalMediaContainer == other.useOriginalMediaContainer &&
      cliPath == other.cliPath
  }
}
