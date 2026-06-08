# Feature Set

Pontificate is Linux-first video editing without the usual rough edges. The editor should feel approachable on day one while still having a serious core for color, subtitles, timing, and export.

## Implemented Foundation

- Linux-first Zig 0.16 core and Qt 5 Widgets shell.
- Media import by extension for common video, audio, image, and subtitle files.
- Core media library records with stable asset IDs, display names, source paths, kind, status, and import order.
- Duplicate detection for repeated imports of the same selected path.
- Missing/offline media status preserved in project state.
- JSON project save/load with schema version `1`.
- Default timeline tracks for video, audio, subtitles, and adjustment/grade.
- Asset-backed timeline clips with asset references, start time, source in, duration, opacity placeholder, and blend mode placeholder.
- C ABI with opaque project handles and caller-owned summary buffers for media and timeline rows.
- Qt Library rows populated from core summaries.
- Qt action to add a selected Library asset to the timeline.
- Timeline rendering from core clip summaries while preserving the existing zoom slider behavior.
- Open/save dialogs for JSON project smoke workflows.
- Core validation through Zig tests plus CMake/Qt build validation.

## Editing

Planned editing scope:

- media library with bins, metadata, search, thumbnails, and missing-media relinking
- layered video, audio, subtitle, and adjustment tracks
- cuts, trims, split edits, clip cropping, transforms, opacity, fades, and blend modes
- timeline zoom, pan, snapping, ripple delete, in/out ranges, markers, and stable playhead navigation
- linked and unlinked audio-video editing
- track mute, solo, lock, visibility, and enable controls
- basic transitions built on the same property/keyframe model as effects
- configurable keyboard shortcuts

## Keyframes

Keyframes are a core primitive, not a late effect feature.

```text
property path + time + value + interpolation
```

This should drive transform, crop, opacity, blend amount, transition progress, color controls, subtitle position, subtitle style overrides, and future masks.

## Color Darkroom

Future work:

- dedicated grading workspace
- exposure, contrast, saturation, temperature, tint, curves, wheels, and LUT import
- scopes: waveform, RGB parade, vectorscope, and histogram
- color-management model for project, display, and export transforms
- before/after comparison and grade bypass
- blend modes and adjustment layers that can be keyframed

## Subtitles

Future work beyond basic subtitle file classification:

- import and export SRT, VTT, and ASS/SSA where practical
- edit subtitles in place on the timeline and in a text-focused panel
- global subtitle styles with per-cue overrides
- local Google Fonts support through the system font stack or app-managed font library
- Whisper-based subtitle generation and selected-range checking
- speaker labels, safe-area guides, and caption preview
- timing tools: shift, stretch, split, merge, snap to speech, and snap to cuts
- export as burned-in subtitles, embedded subtitles, or sidecar files

## Audio

Future work:

- waveform display
- gain, fades, pan, mute, solo, and normalization
- basic EQ, compression, and noise cleanup as later built-ins
- sync-safe handling for linked audio/video clips

## Reliability And Performance

Partially started:

- stable project format with schema versioning
- graceful offline media records for missing sources

Future work:

- command-based undo and redo across every edit surface
- autosave, crash recovery, and project backups
- proxy generation, render cache, preview quality controls, and cache invalidation
- project migrations
- media relinking
- deterministic render planning with test coverage in the Zig core

## Export

Future work:

- render selected range or full timeline
- export queue with presets for common web, archival, and audio-only outputs
- sidecar subtitle export and burn-in controls
- predictable hardware/software encoding choices on Linux
- clear error reporting when codecs, fonts, media, or hardware acceleration are unavailable
