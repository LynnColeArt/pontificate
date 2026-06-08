# Architecture

Pontificate keeps a hard boundary between the editor core and the desktop UI. The current implementation is a foundation slice: media import, project persistence, a C ABI, and initial timeline clips are real. Playback, rendering, trim tools, waveform generation, color processing, and subtitle generation are not implemented yet.

## Core

The Zig core owns the behavior that must remain deterministic and testable:

- project file loading and saving
- media library metadata
- default timeline tracks and asset-backed timeline clips
- keyframes and interpolation
- subtitle cues and style cascade
- missing/offline media status

Future core work should add:

- timeline edit operations such as trim, ripple, split edits, markers, and linked audio/video relationships
- editable property paths
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

Timeline state is modeled in the core and projected into the UI:

- default tracks: video, audio, subtitle, and adjustment
- clips with stable IDs, referenced media asset IDs, track IDs/indexes, timeline start, source in, duration, opacity, and blend mode placeholders
- clip summaries derived from project/media state for UI display

The Qt shell owns presentation state:

- zoom and scroll position
- playhead and selection state
- widget selection and file dialogs

Future timeline edits should resolve into deterministic core operations so undo, autosave, collaboration-friendly project files, and headless tests all see the same state.

## Project File

Project files use JSON schema version `1`. The current shape stores:

- `schema_version`
- `project_id`
- `assets` with stable IDs, display names, reference paths, media kind, status, optional duration, optional dimensions, and import order
- `timeline.tracks` with the default track identifiers and display labels
- `timeline.clips` with asset references and simple timeline placement fields

Media paths are reference-based. Importing a known media extension whose file is not currently readable creates an offline asset with `missing` status. Loading a project revalidates paths and marks unavailable sources as missing instead of dropping them.

## UI

Qt owns the editor surface:

- media library
- preview and transport
- timeline interaction
- timeline zoom controls
- inspector controls

The UI calls into the core through `core/include/pontificate_core.h`. The ABI exposes an opaque `PontificateProject` handle, fixed status codes, import/save/load functions, and caller-owned summary buffers. Qt never owns Zig strings or project internals; it asks the core for compact media and clip summaries and stores only widget selection/presentation state.

The summary buffers are pipe-delimited display strings for this foundation. They are sufficient for the current Qt shell, but a later mission may replace them with richer typed ABI structs once the UI needs more fields and escaping guarantees.

## Candidate Native Libraries

- FFmpeg: probing, decoding, encoding, export, filter support
- GStreamer/GES: timeline playback and non-linear editing evaluation
- libplacebo/OpenColorIO: GPU color transforms and color-management seriousness
- HarfBuzz/FreeType/fontconfig: local font discovery and subtitle shaping
- Whisper.cpp or faster-whisper: local transcription and subtitle checking
