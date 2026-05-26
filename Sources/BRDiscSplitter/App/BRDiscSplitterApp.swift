import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
  private static var retainedDelegate: AppDelegate?

  private let model = AppModel()
  private var mainWindow: NSWindow?

  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    retainedDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    UserDefaults.standard.set(true, forKey: "ApplePersistenceIgnoreState")
    UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(languageDidChange),
      name: .appLanguageDidChange,
      object: nil
    )
    buildMainMenu()
    showMainWindow()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    showMainWindow()
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
    false
  }

  func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
    false
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.action {
    case #selector(chooseInput):
      return !model.isBusy
    case #selector(startExtraction):
      return model.canStart
    case #selector(cancelExtraction):
      return model.isRunning
    default:
      return true
    }
  }

  @objc private func chooseInput() {
    model.chooseInput()
  }

  @objc private func startExtraction() {
    model.start()
  }

  @objc private func cancelExtraction() {
    model.cancel()
  }

  @objc private func languageDidChange() {
    buildMainMenu()
  }

  private func showMainWindow() {
    if mainWindow == nil {
      let rootView = ContentView(model: model)
        .frame(
          minWidth: ContentView.minimumContentSize.width,
          minHeight: ContentView.minimumContentSize.height
        )
        .onAppear { [model] in
          model.bootstrap()
        }

      let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: ContentView.initialContentSize),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
      )
      window.title = "BRDisc Splitter"
      window.isRestorable = false
      window.isReleasedWhenClosed = false
      window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
      window.contentView = NSHostingView(rootView: rootView)
      mainWindow = window
    }

    if let mainWindow {
      center(window: mainWindow)
      mainWindow.makeKeyAndOrderFront(nil)
      mainWindow.orderFrontRegardless()
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func center(window: NSWindow) {
    guard let screen = NSScreen.main else {
      window.center()
      return
    }

    let visibleFrame = screen.visibleFrame
    var frame = window.frame
    frame.origin = NSPoint(
      x: visibleFrame.midX - frame.width / 2,
      y: visibleFrame.midY - frame.height / 2
    )
    window.setFrame(frame, display: true, animate: false)
  }

  private func buildMainMenu() {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu(title: "BRDisc Splitter")
    appMenu.addItem(
      withTitle: L10n.string("app.quit"),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    let fileMenuItem = NSMenuItem()
    let fileMenu = NSMenu(title: L10n.string("menu.file"))
    fileMenu.addItem(
      withTitle: L10n.string("menu.chooseInput"),
      action: #selector(chooseInput),
      keyEquivalent: "o"
    )
    fileMenu.addItem(
      withTitle: L10n.string("menu.start"),
      action: #selector(startExtraction),
      keyEquivalent: "\r"
    )
    fileMenu.addItem(
      withTitle: L10n.string("menu.cancel"),
      action: #selector(cancelExtraction),
      keyEquivalent: "."
    )
    fileMenuItem.submenu = fileMenu
    mainMenu.addItem(fileMenuItem)

    NSApp.mainMenu = mainMenu
  }
}
