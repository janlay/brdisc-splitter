import Foundation

enum PathDefaults {
  static func defaultOutputDirectory() -> String {
    let fileManager = FileManager.default
    let movies = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Movies")

    if fileManager.fileExists(atPath: movies.path) {
      return movies.path
    }

    return fileManager.homeDirectoryForCurrentUser.path
  }

  static func defaultCLIPath() -> String {
    let fileManager = FileManager.default

    if let explicitPath = ProcessInfo.processInfo.environment["BRDISC_SPLITTER_CLI"],
      fileManager.fileExists(atPath: explicitPath)
    {
      return explicitPath
    }

    if let resourcePath = Bundle.main.resourceURL?.appendingPathComponent("brdisc-splitter").path,
      fileManager.fileExists(atPath: resourcePath)
    {
      return resourcePath
    }

    let sourceResource = URL(fileURLWithPath: fileManager.currentDirectoryPath)
      .appendingPathComponent("Sources/BRDiscSplitter/Resources/brdisc-splitter")
    if fileManager.fileExists(atPath: sourceResource.path) {
      return sourceResource.path
    }

    let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    if let path = findCLI(startingAt: currentDirectory) {
      return path
    }

    if let executable = CommandLine.arguments.first {
      let executableDirectory = URL(fileURLWithPath: executable).deletingLastPathComponent()
      if let path = findCLI(startingAt: executableDirectory) {
        return path
      }
    }

    if let path = findCLI(startingAt: Bundle.main.bundleURL) {
      return path
    }

    return currentDirectory.appendingPathComponent("brdisc-splitter").path
  }

  private static func findCLI(startingAt url: URL) -> String? {
    let fileManager = FileManager.default
    var cursor = url.standardizedFileURL

    for _ in 0..<8 {
      let candidate = cursor.appendingPathComponent("brdisc-splitter")
      if fileManager.fileExists(atPath: candidate.path) {
        return candidate.path
      }

      let parent = cursor.deletingLastPathComponent()
      if parent.path == cursor.path {
        break
      }
      cursor = parent
    }

    return nil
  }
}
