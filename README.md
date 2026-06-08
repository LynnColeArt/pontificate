# Pontificate

Pontificate is an experimental Linux-first video editor built around a Zig editing core and a Qt desktop shell.

The product thesis is simple: give Linux creators a video editor that is approachable, capable, and low-friction. The early target is layered timeline editing, cropping, cutting, timeline zoom, basic transitions, blend modes, a darkroom-style color workspace, and subtitle import/edit/generation workflows that can use local Google Fonts globally or per cue.

## Current Status

This repository now has the first editor-foundation slice in place. It currently includes:

- A Zig 0.16 core with media classification, project state, JSON schema v1 persistence, default timeline tracks, asset-backed timeline clips, deterministic split/trim/move edits, and scalar opacity keyframes.
- Optional `ffprobe` metadata probing for local media files, with explicit unprobed, unavailable, failed, malformed, unsupported, and available states.
- Project JSON that persists clip media kind, `opacity_keyframes`, probe status, and probe metadata while still loading older schema-1 clips/assets that do not have those newer fields.
- A C ABI with an opaque project handle, import/save/load calls, caller-owned summary buffers, media/timeline/probe summary functions, probe execution, and timeline editing calls for split, trim, move, opacity keyframe set, and opacity evaluation.
- A Qt 5 Widgets shell that starts with a real core project, imports local files into the Library panel, displays known probe metadata, can explicitly probe selected assets, previews selected still images or one extracted video frame, adds selected assets to the timeline, refreshes clips from core summaries, preserves timeline zoom, exposes first-pass edit controls, and can save/load project JSON.
- A small Zig CLI that can create/import/save a project, report the available timeline edit/keyframe operations, and inspect saved project assets with probe status/metadata plus clip placement and opacity evaluation.

This is still not a complete video editor. Playback, continuous decoding, scrub transport, render/export, thumbnails, waveforms, full transitions, crop/transform tools, darkroom color processing, subtitle editing/import/export, Whisper subtitle generation, proxy/cache workflows, and packaged release artifacts are future work. Media files are reference-based; importing or loading a project records paths and missing/offline state, and preview extraction is temporary display state only.

## Long-Term Product Direction

- Linux-first installation and runtime behavior.
- Timeline editing that includes zoom, snapping, ripple workflows, trim handles, markers, and linked audio/video.
- A darkroom-style color page with scopes and real color-management ambition.
- Subtitles as editable media: import, in-place editing, global/per-cue styling, local fonts, Whisper generation/checking, and flexible export.
- The practical basics that make editors trustworthy: undo/redo, autosave, recovery, proxy/cache workflows, media relinking, waveform audio, keyboard shortcuts, and export presets.

See [docs/FEATURES.md](docs/FEATURES.md) and [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for the working product shape.

## Stack Direction

- Zig owns current deterministic editor logic for the project model, media library, timeline state, timeline edits, and opacity keyframes. Future core work should also own subtitle editing, render planning, and native media bindings.
- Qt owns the interactive desktop shell.
- FFmpeg, GStreamer/GES, libplacebo/OpenColorIO, HarfBuzz/FreeType, and Whisper integrations are candidates for the media, color, text, and transcription layers.

## Build

Requirements already verified on this machine:

- Zig 0.16.0
- Qt 5.15.13 development packages
- CMake 3.28.3
- Optional runtime tools for probe/preview: `ffprobe` and `ffmpeg`

Run the Zig core tests:

```sh
zig build test
```

Run the core CLI:

```sh
zig build run
```

Create a small project from media paths:

```sh
zig build run -- import-save demo-project /tmp/demo.pontificate.json /path/to/clip.mp4 /path/to/audio.wav
```

Inspect a saved project:

```sh
zig build run -- inspect /tmp/demo.pontificate.json
```

Build the Qt application:

```sh
cmake -S . -B build
cmake --build build
```

Check diff hygiene before handing a change to review:

```sh
git diff --check
```

Launch it:

```sh
./build/pontificate
```

## Current Qt Workflow

1. Launch the app.
2. Use **Import** to select one or more local media/subtitle files.
3. Select a Library row and use **Probe** when `ffprobe` is available to populate duration, dimensions, frame rate, and stream flags.
4. Use **Preview** to display a still image directly or ask `ffmpeg` for a temporary representative video frame.
5. Use **Add** or double-click to create an initial asset-backed timeline clip; probed video/audio duration is used when available.
6. Use the timeline zoom controls to scale the displayed clips horizontally.
7. Select a timeline clip and use the Edit dock to split, trim, or move it.
8. Set an opacity keyframe, evaluate opacity at a clip-local time, and confirm status messages report the result.
9. Confirm the timeline redraws from core summaries and keeps the selected zoom level after edits.
10. Use **Save** to write a JSON project, then **Open** to load it again and refresh Library/Timeline state from the core.
