import Foundation
import XCTest
@testable import BRDiscSplitter

final class SplitterOptionsTests: XCTestCase {
  func testCommandArgumentsIncludeCommonAndAdvancedOptions() {
    var options = SplitterOptions()
    options.inputPath = "/tmp/Show.iso"
    options.outputDirectory = "/tmp/Output"
    options.mediaName = "Show Name"
    options.season = 2
    options.episodeStart = 4
    options.jobs = 3
    options.minDuration = 1800
    options.dryRun = true
    options.overwrite = true
    options.noMediaDir = true
    options.noSeasonDir = true
    options.useOriginalMediaContainer = true

    XCTAssertEqual(
      options.commandArguments,
      [
        "-i", "/tmp/Show.iso",
        "-o", "/tmp/Output",
        "--name", "Show Name",
        "--season", "2",
        "--episode-start", "4",
        "--min-duration", "1800",
        "--jobs", "3",
        "--dry-run",
        "--no-media-dir",
        "--no-season-dir",
        "--use-original-media-container",
        "--overwrite"
      ]
    )
  }

  func testCommandArgumentsOmitBlankMediaName() {
    var options = SplitterOptions()
    options.inputPath = "/tmp/Movie.iso"
    options.outputDirectory = "/tmp/Output"
    options.mediaName = "  "

    XCTAssertFalse(options.commandArguments.contains("--name"))
  }

  func testForcedDryRunArgumentsDoNotMutateOptionState() {
    var options = SplitterOptions()
    options.inputPath = "/tmp/Movie.iso"
    options.outputDirectory = "/tmp/Output"
    options.dryRun = false

    XCTAssertTrue(options.commandArguments(forceDryRun: true).contains("--dry-run"))
    XCTAssertFalse(options.commandArguments.contains("--dry-run"))
  }

  func testMediaPlanParserReadsDryRunOutput() {
    let output = """
    Input: /Volumes/Disc
    Output: /tmp/Output
    Detected media type: series (input path or media name has series hints)
    Planned extraction:
    00:42:10  00001.m2ts -> Show/Show S01E01.mkv
    00:43:05  00002.m2ts -> Show/Show S01E02.mkv
    """

    let plan = MediaPlanParser.parse(output, outputDirectory: "/tmp/Output")

    XCTAssertEqual(plan.mediaType, "series")
    XCTAssertEqual(plan.items.count, 2)
    XCTAssertEqual(plan.items[0].durationText, "00:42:10")
    XCTAssertEqual(plan.items[0].sourceName, "00001.m2ts")
    XCTAssertEqual(plan.items[0].outputDisplayPath, "Show/Show S01E01.mkv")
    XCTAssertEqual(plan.items[0].outputPath, "/tmp/Output/Show/Show S01E01.mkv")
  }

  func testMediaPlanParserReadsPlayableMetadata() {
    let output = """
    Input: /Volumes/Disc
    Output: /tmp/Output
    Detected media type: movie (only one candidate stream)
    Planned extraction:
    01:42:10  00001.m2ts -> Movie/Movie.mkv
        index: 1
        source: /Volumes/Disc/BDMV/STREAM/00001.m2ts
        size: 24.5 GB (26306674688 bytes)
        video: h264 1920x1080 High
        audio: #1 English (eng) dts 6ch 5.1; #2 Japanese (jpn) ac3 2ch stereo
        subtitles: #3 Chinese (zho) hdmv_pgs_subtitle
    """

    let plan = MediaPlanParser.parse(output, outputDirectory: "/tmp/Output")

    XCTAssertEqual(plan.items.count, 1)
    XCTAssertEqual(plan.items[0].index, 1)
    XCTAssertEqual(plan.items[0].sourcePath, "/Volumes/Disc/BDMV/STREAM/00001.m2ts")
    XCTAssertEqual(plan.items[0].sizeText, "24.5 GB")
    XCTAssertEqual(plan.items[0].videoText, "h264 1920x1080 High")
    XCTAssertEqual(plan.items[0].audioText, "#1 English (eng) dts 6ch 5.1; #2 Japanese (jpn) ac3 2ch stereo")
    XCTAssertEqual(plan.items[0].subtitlesText, "#3 Chinese (zho) hdmv_pgs_subtitle")
  }

  func testWindowContentFitUsesMeasuredHeight() {
    let policy = WindowContentFitPolicy()

    XCTAssertEqual(
      policy.targetContentSize(
        measuredSize: CGSize(width: 680.2, height: 241.1),
        visibleFrame: nil
      ),
      CGSize(width: 681, height: 242)
    )

    XCTAssertEqual(
      policy.targetContentSize(
        measuredSize: CGSize(width: 680.2, height: 512.4),
        visibleFrame: nil
      ),
      CGSize(width: 681, height: 513)
    )
  }

  func testWindowContentFitClampsToVisibleFrame() {
    let policy = WindowContentFitPolicy(displayPadding: 10)

    XCTAssertEqual(
      policy.targetContentSize(
        measuredSize: CGSize(width: 1_000, height: 900),
        visibleFrame: CGRect(x: 0, y: 0, width: 700, height: 500)
      ),
      CGSize(width: 680, height: 480)
    )
  }

  @MainActor
  func testUseInputISOParentDirectoryForOutput() throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .standardizedFileURL
    let iso = directory.appendingPathComponent("Show.iso")

    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock {
      try? fileManager.removeItem(at: directory)
    }

    XCTAssertTrue(fileManager.createFile(atPath: iso.path, contents: Data()))

    let model = AppModel()
    model.options.inputPath = iso.path
    model.options.outputDirectory = "/tmp/Other"

    XCTAssertEqual(model.inputISOParentDirectory, directory.path)

    model.useInputISOParentDirectoryForOutput()

    XCTAssertEqual(model.options.outputDirectory, directory.path)
    XCTAssertEqual(Array(model.options.commandArguments.prefix(4)), ["-i", iso.path, "-o", directory.path])
  }
}
