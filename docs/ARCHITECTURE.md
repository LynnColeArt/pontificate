# Architecture

Pontificate starts with a hard boundary between the editor core and the desktop UI.

## Core

The Zig core should own the behavior that must remain deterministic and testable:

- project file loading and saving
- media library metadata
- timeline tracks, clips, layers, and adjustments
- timeline zoom and edit navigation state
- editable property paths
- keyframes and interpolation
- subtitle cues and style cascade
- command history for undo and redo
- autosave, recovery, project versioning, and migrations
- render graph planning
- proxy and render-cache planning
- media backend integration boundaries

The keyframe primitive is intentionally general:

```text
property path + time + value + interpolation
```

That single model should cover opacity, transform, crop, blend amount, transition progress, subtitle position, local subtitle styling, and color controls.

## Timeline

Timeline behavior should be modeled in the core and projected into the UI:

- zoom and scroll position
- playhead and selection state
- snapping targets
- ripple behavior
- trim modes
- markers and in/out ranges
- linked audio/video relationships

The Qt shell can own interaction details, but timeline edits should resolve into deterministic core operations so undo, autosave, collaboration-friendly project files, and future headless tests all see the same state.

## UI

Qt owns the editor surface:

- media library
- preview and transport
- timeline interaction
- timeline zoom controls
- inspector controls
- color workspace
- subtitle editing workspace

The UI should call into the core through a small C ABI first. That keeps the shell replaceable while the project model and media logic mature.

## Candidate Native Libraries

- FFmpeg: probing, decoding, encoding, export, filter support
- GStreamer/GES: timeline playback and non-linear editing evaluation
- libplacebo/OpenColorIO: GPU color transforms and color-management seriousness
- HarfBuzz/FreeType/fontconfig: local font discovery and subtitle shaping
- Whisper.cpp or faster-whisper: local transcription and subtitle checking
