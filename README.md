# Pontificate

Pontificate is an experimental Linux-first video editor built around a Zig editing core and a Qt desktop shell.

The product thesis is simple: give Linux creators a video editor that is approachable, capable, and low-friction. The early target is layered timeline editing, cropping, cutting, timeline zoom, basic transitions, blend modes, a darkroom-style color workspace, and subtitle import/edit/generation workflows that can use local Google Fonts globally or per cue.

## Current Status

This repository is a fresh scaffold. It currently includes:

- A Zig 0.16 core library with timeline-adjacent data types, starter project stats, subtitle models, blend modes, and keyframe evaluation.
- A C ABI header for the future app/library boundary.
- A Qt 5 Widgets shell with library, preview, inspector, timeline panes, and timeline zoom controls.
- A tiny Zig CLI and unit tests for the core.

## Product Commitments

- Linux-first installation and runtime behavior.
- Timeline editing that includes zoom, snapping, ripple workflows, trim handles, markers, and linked audio/video.
- A darkroom-style color page with scopes and real color-management ambition.
- Subtitles as editable media: import, in-place editing, global/per-cue styling, local fonts, Whisper generation/checking, and flexible export.
- The practical basics that make editors trustworthy: undo/redo, autosave, recovery, proxy/cache workflows, media relinking, waveform audio, keyboard shortcuts, and export presets.

See [docs/FEATURES.md](docs/FEATURES.md) and [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for the working product shape.

## Stack Direction

- Zig owns deterministic editor logic: project model, timeline state, subtitles, keyframes, render planning, and native media bindings.
- Qt owns the interactive desktop shell.
- FFmpeg, GStreamer/GES, libplacebo/OpenColorIO, HarfBuzz/FreeType, and Whisper integrations are candidates for the media, color, text, and transcription layers.

## Build

Requirements already verified on this machine:

- Zig 0.16.0
- Qt 5.15.13 development packages
- CMake 3.28.3

Run the Zig core tests:

```sh
zig build test
```

Run the core CLI:

```sh
zig build run
```

Build the Qt application:

```sh
cmake -S . -B build
cmake --build build
```

Launch it:

```sh
./build/pontificate
```
