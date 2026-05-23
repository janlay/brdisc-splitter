# brdisc-splitter

[中文](README-zh.md) | English

A Bash command-line tool for extracting media streams from Blu-ray directory structures or ISO files without transcoding.

## Dependencies

- `ffmpeg`
- `ffprobe`
- `jq`

ISO handling on macOS also uses the system tools `hdiutil` and `plutil`. On Linux, ISO auto-mounting prefers `udisksctl`; otherwise it requires a root-capable read-only loop mount.

## Usage

```bash
./brdisc-splitter -i INPUT [options]
```

The tool automatically detects whether the source is a movie or a TV series. Movies use the longest candidate stream. TV episodes are generated from `.m2ts` streams in filename order. Output defaults to the mkv container without transcoding.

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

Common options:

- `-o, --output DIR`: Output directory. Defaults to the current directory.
- `--min-duration SEC`: Filter out short streams. Defaults to `1200`.
- `--no-media-dir`: Do not create a media-name directory.
- `--no-season-dir`: Never create a `Season NN` directory.
- `--episode-start N`: Set the first episode number.
- `--use-original-media-container`: Preserve the source media container, for example output `.m2ts`.
- `--overwrite`: Overwrite existing output files.

TV output creates a `Season NN` directory only when multiple seasons are detected. Single-season output is written directly under the media directory, while filenames still include `SxxEyy`.

During extraction, temporary files use `final-output-name.partial`. On rerun, completed final files are skipped automatically, and stale `.partial` files are re-extracted.

## Current Limitations

- The current version scans `BDMV/STREAM/*.m2ts` directly and does not parse `.mpls` playlists.
- Movie/series detection is heuristic; Blu-ray structures do not provide reliable media-type metadata.
- Multi-season detection is based on season ranges or multiple season markers in the input path or media name.
- The tool does not split a single long title into episodes by chapter.
- ISO auto-mounting is supported only on macOS and Linux. On other platforms, mount the ISO manually and pass the mounted directory.
