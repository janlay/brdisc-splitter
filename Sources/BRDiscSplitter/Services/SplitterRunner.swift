import Foundation

final class SplitterRunner {
  enum RunnerError: LocalizedError {
    case alreadyRunning

    var errorDescription: String? {
      switch self {
      case .alreadyRunning:
        return L10n.string("runner.error.busy")
      }
    }
  }

  private let lock = NSLock()
  private var process: Process?
  private var outputPipe: Pipe?
  private var errorPipe: Pipe?

  func run(
    scriptPath: String,
    arguments: [String],
    workingDirectory: URL,
    onOutput: @escaping (String) -> Void,
    onCompletion: @escaping (Int32) -> Void
  ) throws {
    lock.lock()
    if process != nil {
      lock.unlock()
      throw RunnerError.alreadyRunning
    }
    lock.unlock()

    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [scriptPath] + arguments
    process.currentDirectoryURL = workingDirectory
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    outputPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      onOutput(String(decoding: data, as: UTF8.self))
    }

    errorPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      onOutput(String(decoding: data, as: UTF8.self))
    }

    process.terminationHandler = { [weak self] terminatedProcess in
      outputPipe.fileHandleForReading.readabilityHandler = nil
      errorPipe.fileHandleForReading.readabilityHandler = nil

      self?.clear(process: terminatedProcess)
      onCompletion(terminatedProcess.terminationStatus)
    }

    lock.lock()
    self.process = process
    self.outputPipe = outputPipe
    self.errorPipe = errorPipe
    lock.unlock()

    do {
      try process.run()
    } catch {
      outputPipe.fileHandleForReading.readabilityHandler = nil
      errorPipe.fileHandleForReading.readabilityHandler = nil
      clear(process: process)
      throw error
    }
  }

  func cancel() {
    guard let process = currentProcess() else {
      return
    }

    process.interrupt()

    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
      if process.isRunning {
        process.terminate()
      }
    }
  }

  private func currentProcess() -> Process? {
    lock.lock()
    defer { lock.unlock() }
    return process
  }

  private func clear(process terminatedProcess: Process) {
    lock.lock()
    defer { lock.unlock() }

    if process === terminatedProcess {
      process = nil
      outputPipe = nil
      errorPipe = nil
    }
  }
}
