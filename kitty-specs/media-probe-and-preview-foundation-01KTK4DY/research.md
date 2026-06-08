# Research: Media Probe And Preview Foundation

## Decisions

### Use Optional FFmpeg Command-Line Tools

Use `ffprobe` for metadata and `ffmpeg` for one-frame preview extraction in this mission. Treat both as optional Linux runtime tools.

Rationale:

- Broad codec/container support matters immediately, but native decoder bindings would expand build, packaging, and memory-safety scope too early.
- Process invocation keeps the boundary reviewable and allows deterministic parser tests against fixture JSON.
- Tool absence can become an explicit product state instead of an install-time failure.

Implementation notes:

- Invoke tools with argv arrays, not shell strings.
- Keep process execution localized to `core/src/probe.zig` for metadata and `ui/src/main.cpp` for temporary preview extraction.
- Do not introduce a persistent media cache.

### Probe Explicitly Before Auto-Probe

Use explicit probe actions in the core, CLI, and Qt shell for this mission.

Rationale:

- Import stays responsive and predictable.
- The app has no background job queue, progress, or cancellation surface yet.
- Missing-tool and failure states are easier to validate when probe is user-triggered.

Deferred option:

- A later media-job mission can auto-probe on import using the same project operation once progress/cancel behavior exists.

### Separate Media Availability From Probe Status

Keep existing `MediaStatus` for path availability and support. Add a distinct `ProbeStatus` for metadata knowledge.

Rationale:

- A file can be missing on load while still having useful persisted probe metadata.
- An available file can be unprobed, malformed, or unsupported.
- UI and CLI output need to tell the user which fact is unknown.

### Keep Preview Display-Owned By Qt

Qt should display still images directly and extract video frames to temporary images with `QProcess` and Qt temporary-file APIs.

Rationale:

- Preview pixels are UI state, not project truth.
- A core-owned preview cache would create lifecycle and cleanup obligations outside this mission.
- Future playback, scrub preview, thumbnails, scopes, and color pipeline work can replace this path without changing persisted project metadata.

### Do Not Rewrite Existing Clips After Probe

Use known probed duration for clips created after metadata exists. Existing clips are not automatically conformed.

Rationale:

- Timeline edits should not shift as a side effect of a later probe.
- Explicit conform/relink behavior belongs in a future media-management mission.

## Evidence And Constraints

- The current core already stores optional `duration_seconds` and `dimensions` on media assets, but values are not produced from real media.
- The current project file schema is `1`; optional probe fields allow old files to load without a breaking schema bump.
- The Qt shell already consumes pipe-delimited summaries through caller-owned C ABI buffers, so a probe summary can follow the same ownership pattern.
- The charter requires Linux-first validation and declared dependencies. Optional FFmpeg tools satisfy the product need without becoming required build dependencies.

## Open Risks

- `ffprobe` JSON differs across containers and codecs; parser tests must cover missing fields and `N/A` values.
- Synchronous process calls can block UI if used carelessly; the Qt surface must keep probe/preview explicit.
- Pipe-delimited summary strings remain display-oriented and should not become the long-term structured ABI.
