# Architecture

Pontificate keeps a hard boundary between the editor core and the desktop UI. The current implementation is a foundation slice: media import, optional media probing, project persistence, a C ABI, asset-backed timeline clips, deterministic split/trim/move edits, scalar opacity keyframes, first-pass Qt edit controls, and display-only still/frame preview are real. Playback, continuous decoding, rendering/export, thumbnails, waveforms, full transitions, color processing, subtitle editing, Whisper integration, and packaging are not implemented yet.

## Core

The Zig core owns the behavior that must remain deterministic and testable:

- project file loading and saving
- media library metadata
- probe status and parsed media metadata from optional `ffprobe`
- default timeline tracks and asset-backed timeline clips
- timeline edit validation for split, trim, move, and opacity keyframe operations
- scalar opacity keyframes and interpolation
- project JSON compatibility for schema-1 files with or without clip keyframe data
- static starter subtitle cue/style data and subtitle media classification
- missing/offline media status

## Media Probe And Preview

Media files remain reference-based. The core can explicitly probe a selected asset by invoking `ffprobe` with argv arguments and parsing JSON into typed metadata:

- probe status: unprobed, available, tool unavailable, failed, malformed, or unsupported
- optional duration, dimensions, and frame rate
- video, audio, and subtitle stream flags
- display labels for container and codecs when available

Probe metadata is persisted in schema-1 JSON as optional fields so old project files continue to load. Loading a project may revalidate media availability, but it does not discard persisted probe metadata when a source path is offline.

Preview pixels are UI-owned. Qt loads still images directly and asks `ffmpeg` to extract one temporary PNG for video preview. The temporary frame is display state only: it is not stored in project JSON, not cached persistently, and not part of a playback pipeline.

Future core work should add:

- broader timeline edit operations such as ripple, roll, slip, slide, markers, and linked audio/video relationships
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

The shipped property path is scalar clip opacity. That same model should later cover transform, crop, blend amount, transition progress, subtitle position, local subtitle styling, and color controls.

## Timeline

Timeline state is modeled in the core and projected into the UI:

- default tracks: video, audio, subtitle, and adjustment
- clips with stable IDs, referenced media asset IDs, media kind, track IDs/indexes, timeline start, source in, duration, opacity, opacity keyframes, and blend mode placeholders
- validated edit operations that reject invalid clip indexes, times, durations, incompatible tracks, and keyframe values before mutation
- deterministic clip summaries derived from project/media state for UI display, sorted by track, time, and clip ID

The Qt shell owns presentation state:

- zoom and scroll position
- playhead and selection state
- widget selection and file dialogs
- first-pass edit widgets that pass selected clip indexes and numeric edit fields into the C ABI

Future timeline edits should keep resolving into deterministic core operations so undo, autosave, collaboration-friendly project files, and headless tests all see the same state.

## Project File

Project files use JSON schema version `1`. The current shape stores:

- `schema_version`
- `project_id`
- `assets` with stable IDs, display names, reference paths, media kind, status, optional duration, optional dimensions, and import order
- `timeline.tracks` with the default track identifiers and display labels
- `timeline.clips` with asset references, media kind, timeline placement fields, opacity, blend mode, and optional `opacity_keyframes`
- optional asset `probe_status` and `metadata` fields for probed duration, dimensions, frame rate, stream flags, and codec/container labels

Media paths are reference-based. Importing a known media extension whose file is not currently readable creates an offline asset with `missing` status. Loading a project revalidates paths and marks unavailable sources as missing instead of dropping them. Older schema-1 clips without `opacity_keyframes` load with an empty keyframe curve.

## UI

Qt owns the editor surface:

- media library
- preview and transport
- timeline interaction
- timeline zoom controls
- inspector controls

The UI calls into the core through `core/include/pontificate_core.h`. The ABI exposes an opaque `PontificateProject` handle, fixed status codes, import/save/load functions, and caller-owned summary buffers. Qt never owns Zig strings or project internals; it asks the core for compact media and clip summaries and stores only widget selection/presentation state.

Timeline editing currently crosses that boundary through:

```c
uint32_t pontificate_project_split_clip(PontificateProject *project, uint32_t clip_index, double split_time);
uint32_t pontificate_project_trim_clip(PontificateProject *project, uint32_t clip_index, double timeline_start, double source_in, double duration);
uint32_t pontificate_project_move_clip(PontificateProject *project, uint32_t clip_index, uint32_t track_index, double timeline_start);
uint32_t pontificate_project_set_clip_opacity_keyframe(PontificateProject *project, uint32_t clip_index, double clip_time, double value);
double pontificate_project_evaluate_clip_opacity(const PontificateProject *project, uint32_t clip_index, double clip_time, uint32_t *status_out);
uint32_t pontificate_project_probe_asset(PontificateProject *project, uint32_t index);
uint32_t pontificate_project_asset_probe_summary(const PontificateProject *project, uint32_t index, char *buffer, uint32_t buffer_len);
```

These functions address clips by the current sorted clip index. Qt refreshes summaries and selection after successful edits because split and move operations can change clip ordering.

The summary buffers are pipe-delimited display strings for this foundation. They are sufficient for the current Qt shell, but a later mission may replace them with richer typed ABI structs once the UI needs more fields and escaping guarantees.

## Candidate Native Libraries

- FFmpeg: probing, decoding, encoding, export, filter support
- GStreamer/GES: timeline playback and non-linear editing evaluation
- libplacebo/OpenColorIO: GPU color transforms and color-management seriousness
- HarfBuzz/FreeType/fontconfig: local font discovery and subtitle shaping
- Whisper.cpp or faster-whisper: local transcription and subtitle checking
