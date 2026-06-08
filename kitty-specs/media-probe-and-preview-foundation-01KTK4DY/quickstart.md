# Quickstart: Media Probe And Preview Foundation

## Validation Commands

```sh
zig build test
zig build run
cmake -S . -B build
cmake --build build
git diff --check
git status --short --branch
```

## Validation Evidence

Last run during WP05:

- `zig build test`: passed
- `zig build run`: passed
- `cmake -S . -B build`: passed
- `cmake --build build`: passed
- `git diff --check`: passed
- `QT_QPA_PLATFORM=offscreen timeout 3s ./build/pontificate`: reached the Qt event loop and exited by timeout as expected

## CLI Smoke Path

```sh
zig build run -- import-save probe-smoke /tmp/pontificate-probe-smoke.json /path/to/media.mp4
zig build run -- inspect /tmp/pontificate-probe-smoke.json
```

If a dedicated probe command is added:

```sh
zig build run -- probe-inspect /tmp/pontificate-probe-smoke.json
```

The output should identify probe status and known metadata without requiring Qt.

## Manual Qt Smoke Path

1. Build the Qt app.
2. Launch the app with no FFmpeg tools installed or with `PATH` adjusted so `ffprobe`/`ffmpeg` are unavailable.
3. Confirm the app launches, imports paths, and reports unavailable probe/preview state without crashing.
4. Restore FFmpeg tools if installed.
5. Import a still image, select it, and refresh preview.
6. Confirm the still image appears scaled in the preview panel.
7. Import a video, run the explicit probe action, and confirm Library metadata updates when `ffprobe` is available.
8. Refresh video preview and confirm either an extracted frame appears or the status bar reports a clear extraction failure.
9. Add a probed video or audio asset to the timeline and confirm the default clip duration uses known positive duration.

## Non-Goals

This mission does not add continuous playback, scrub transport, audio sync, render/export, codec preset UI, thumbnail strips, waveform generation, proxy media, persistent caches, color scopes, LUTs, color management, darkroom grading controls, subtitle editing, Whisper integration, font workflows, or packaging changes.
