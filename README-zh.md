# brdisc-splitter

中文 | [English](README.md)

一个 Bash 命令行工具，用于从蓝光目录结构或 ISO 文件中提取媒体流，不转码。

## 依赖

- `ffmpeg`
- `ffprobe`
- `jq`

macOS 下处理 ISO 还会使用系统工具 `hdiutil` 和 `plutil`。Linux 下自动挂载 ISO 优先使用 `udisksctl`；否则需要 root 环境支持只读 loop mount。

## 用法

```bash
./brdisc-splitter -i INPUT [options]
```

工具会自动检测来源是电影还是剧集。电影使用最长的候选流；剧集按 `.m2ts` 文件名顺序生成剧集文件。默认输出 mkv 容器，不转码。

提取到当前目录：

```bash
./brdisc-splitter -i Movie.iso --name "Movie Name"
```

指定输出目录和并行任务数：

```bash
./brdisc-splitter -i Show.iso -o /path/to/output --name "Show Name" --season 1 --jobs 2
```

只预览提取计划，不写入媒体文件：

```bash
./brdisc-splitter -i Show.iso --dry-run
```

常用选项：

- `-o, --output DIR`：输出目录，默认当前目录。
- `--min-duration SEC`：过滤短流，默认 `1200`。
- `--no-media-dir`：不创建媒体名目录。
- `--no-season-dir`：永不创建 `Season NN` 目录。
- `--episode-start N`：设置起始集号。
- `--use-original-media-container`：保留源媒体容器，例如输出 `.m2ts`。
- `--overwrite`：覆盖已有输出文件。

剧集输出只有在检测到多季时才创建 `Season NN` 目录。单季输出会直接写入媒体目录，文件名仍包含 `SxxEyy`。

提取过程中，临时文件使用 `final-output-name.partial`。再次运行时，已完成的最终文件会自动跳过，残留的 `.partial` 文件会重新提取。

## 当前限制

- 当前版本直接扫描 `BDMV/STREAM/*.m2ts`，不解析 `.mpls` 播放列表。
- 电影/剧集识别是启发式判断；蓝光结构不提供可靠的媒体类型元数据。
- 多季检测基于输入路径或媒体名中的季范围或多个季标记。
- 工具不会将单个长标题按章节切分为多集。
- ISO 自动挂载仅支持 macOS 和 Linux。其他平台请手动挂载 ISO 后传入挂载目录。

## 许可证

见 [LICENSE](LICENSE)。
