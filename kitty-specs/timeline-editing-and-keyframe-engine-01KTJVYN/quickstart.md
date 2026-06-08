# Quickstart: Timeline Editing And Keyframe Engine

## Validation Commands

```sh
zig build test
zig build run
cmake -S . -B build
cmake --build build
git diff --check
git status --short --branch
```

## Manual Qt Smoke Path

1. Launch the Qt app after building.
2. Import a local supported media path.
3. Add the imported asset to the timeline.
4. Adjust timeline zoom.
5. Select a clip.
6. Use the first-pass split, trim, and move controls.
7. Add an opacity keyframe.
8. Confirm the timeline redraws from core summaries and zoom remains applied.

## Non-Goals

This mission does not add playback, decoding, audio/video sync, export, render queues, thumbnails, waveforms, proxies, full transition editing, color-room processing, subtitle editing, Whisper integration, or packaging.
