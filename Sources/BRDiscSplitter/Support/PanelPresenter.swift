import AppKit
import Foundation
import UniformTypeIdentifiers

enum PanelPresenter {
  @MainActor
  static func chooseInput() -> String? {
    let panel = NSOpenPanel()
    panel.title = L10n.string("panel.input.title")
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.treatsFilePackagesAsDirectories = true

    if let isoType = UTType(filenameExtension: "iso") {
      panel.allowedContentTypes = [isoType]
    }

    return panel.runModal() == .OK ? panel.url?.path : nil
  }

  @MainActor
  static func chooseOutputDirectory() -> String? {
    let panel = NSOpenPanel()
    panel.title = L10n.string("panel.output.title")
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false

    return panel.runModal() == .OK ? panel.url?.path : nil
  }

  @MainActor
  static func chooseCLIPath() -> String? {
    let panel = NSOpenPanel()
    panel.title = L10n.string("panel.cli.title")
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false

    return panel.runModal() == .OK ? panel.url?.path : nil
  }
}
