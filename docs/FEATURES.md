# Feature Set

Pontificate is Linux-first video editing without the usual rough edges. The editor should feel approachable on day one while still having a serious core for color, subtitles, timing, and export.

## Editing

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

- dedicated grading workspace
- exposure, contrast, saturation, temperature, tint, curves, wheels, and LUT import
- scopes: waveform, RGB parade, vectorscope, and histogram
- color-management model for project, display, and export transforms
- before/after comparison and grade bypass
- blend modes and adjustment layers that can be keyframed

## Subtitles

- import and export SRT, VTT, and ASS/SSA where practical
- edit subtitles in place on the timeline and in a text-focused panel
- global subtitle styles with per-cue overrides
- local Google Fonts support through the system font stack or app-managed font library
- Whisper-based subtitle generation and selected-range checking
- speaker labels, safe-area guides, and caption preview
- timing tools: shift, stretch, split, merge, snap to speech, and snap to cuts
- export as burned-in subtitles, embedded subtitles, or sidecar files

## Audio

- waveform display
- gain, fades, pan, mute, solo, and normalization
- basic EQ, compression, and noise cleanup as later built-ins
- sync-safe handling for linked audio/video clips

## Reliability And Performance

- command-based undo and redo across every edit surface
- autosave, crash recovery, and project backups
- proxy generation, render cache, preview quality controls, and cache invalidation
- stable project format with schema versioning and migrations
- graceful offline media handling and relinking
- deterministic render planning with test coverage in the Zig core

## Export

- render selected range or full timeline
- export queue with presets for common web, archival, and audio-only outputs
- sidecar subtitle export and burn-in controls
- predictable hardware/software encoding choices on Linux
- clear error reporting when codecs, fonts, media, or hardware acceleration are unavailable
