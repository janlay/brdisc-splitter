# BRDisc Splitter

[中文](README-zh.md) | English

BRDisc Splitter is a macOS app for extracting movie or TV episode streams from Blu-ray ISO files and mounted Blu-ray directories without transcoding. The app provides the normal user workflow; the bundled command-line tool remains available for advanced users and automation.

## macOS App

<p>
  <img src="./images/preview-1.png" alt="BRDisc Splitter prepare screen" width="49%">
  <img src="./images/preview-2.png" alt="BRDisc Splitter input screen" width="49%">
</p>

Build and launch the app from source:

```bash
./script/build_and_run.sh
```

The script builds `dist/BRDisc Splitter.app` through `BRDiscSplitter.xcodeproj` and launches it. Its internal executable is named `BRDiscSplitter`. The GUI uses the bundled `Contents/Resources/brdisc-splitter` script by default; you can pick a different script in the advanced section. The repository-root `./brdisc-splitter` wrapper forwards to the same CLI script and remains callable on its own.

You can also open `BRDiscSplitter.xcodeproj` in Xcode and use the `BRDiscSplitter` scheme to run or test the app.

Basic workflow:

- Prepare a `.iso` file, a Blu-ray root directory, or a `BDMV` directory.
- Drop it into the app or choose it with Browse.
- Review detected movie or episode streams.
- Choose output and extraction options.
- Start extraction and inspect logs only when needed.

## Requirements

BRDisc Splitter uses these external tools:

- `ffmpeg`
- `ffprobe`
- `jq`

ISO handling on macOS also uses the system tools `hdiutil` and `plutil`.

## Advanced CLI Usage

The command-line tool is intended for advanced users, scripting, and automation. It uses the same extraction logic as the app.

```bash
./brdisc-splitter -i INPUT [options]
```

Extract to the current directory:

```bash
./brdisc-splitter -i Movie.iso --name "Movie Name"
```

Set an output directory and parallel job count:

```bash
./brdisc-splitter -i Show.iso -o /path/to/output --name "Show Name" --season 1 --jobs 2
```

Preview the extraction plan without writing media files:

```bash
./brdisc-splitter -i Show.iso --dry-run
```

List playable files and key metadata without writing media files:

```bash
./brdisc-splitter -i Show.iso --list
```

Open the first listed file with the system-associated app without extracting it:

```bash
./brdisc-splitter -i Show.iso --open 1
```

Common CLI options:

- `-o, --output DIR`: Output directory. Defaults to the current directory.
- `--min-duration SEC`: Filter out short streams. Defaults to `1200`.
- `--no-media-dir`: Do not create a media-name directory.
- `--no-season-dir`: Never create a `Season NN` directory.
- `--episode-start N`: Set the first episode number.
- `--use-original-media-container`: Preserve the source media container, for example output `.m2ts`.
- `--overwrite`: Overwrite existing output files.
- `--list`: Print index, duration, file size, video, audio tracks, subtitles, and source path.
- `--open N`: Open the source `.m2ts` file at list index `N` with the system-associated app.

On Linux, CLI ISO auto-mounting prefers `udisksctl`; otherwise it requires a root-capable read-only loop mount.

## Extraction Behavior

BRDisc Splitter automatically detects whether the source is a movie or a TV series. Movies use the longest candidate stream. TV episodes are generated from `.m2ts` streams in filename order. Output defaults to the mkv container without transcoding.

Listing and direct playback reference the `.m2ts` files inside the Blu-ray source. For ISO input, the tool mounts the ISO read-only first; if the tool mounted the ISO itself, `--open` keeps that mount alive until the external open command returns so the player does not lose the source file mid-playback.

TV output creates a `Season NN` directory only when multiple seasons are detected. Single-season output is written directly under the media directory, while filenames still include `SxxEyy`.

During extraction, temporary files use `final-output-name.partial`. On rerun, completed final files are skipped automatically, and stale `.partial` files are re-extracted.

## Current Limitations

- The current version scans `BDMV/STREAM/*.m2ts` directly and does not parse `.mpls` playlists.
- Movie/series detection is heuristic; Blu-ray structures do not provide reliable media-type metadata.
- Multi-season detection is based on season ranges or multiple season markers in the input path or media name.
- The tool does not split a single long title into episodes by chapter.
- ISO auto-mounting is supported only on macOS and Linux. On other platforms, mount the ISO manually and pass the mounted directory.

## License

See [LICENSE](LICENSE).
