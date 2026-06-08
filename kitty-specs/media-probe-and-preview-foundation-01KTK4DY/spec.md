# Mission Specification: Media Probe And Preview Foundation

**Mission Branch**: `kitty/mission-media-probe-and-preview-foundation-01KTK4DY`
**Created**: 2026-06-08
**Status**: Draft
**Input**: User direction: "Nice! Let's do it." after selecting media probe plus preview as the next slice following timeline/keyframe foundation.

## Product Context

Pontificate is a Linux-first Zig core plus Qt desktop video editor. The current editor can import media paths, save/load project JSON, place clips on a timeline, split/trim/move clips, persist opacity keyframes, expose a C ABI, and provide first-pass Qt editing controls. Media files are still reference-based: the app records paths and extension-derived kinds, but it does not inspect real duration, dimensions, frame rate, stream layout, thumbnails, or preview frames.

This mission adds the first real media-understanding layer. It should probe local media files for metadata, persist the useful probe result on assets, expose that metadata to Qt, and add a first-pass preview surface that can show a selected still image or extracted video frame. The mission is deliberately not full playback. It should build the spine for thumbnails, waveforms, scrub preview, subtitle timing, scopes, and export without taking on a player, render graph, proxy cache, or GPU color pipeline yet.

The conservative implementation direction is a process-based FFmpeg bridge: use `ffprobe` for metadata and `ffmpeg` for single-frame extraction when those tools are available. The Zig project model should keep deterministic behavior and testable parsing; external tool absence must be a clear unavailable/degraded state, not a crash.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Probe Imported Media Metadata (Priority: P1)

A creator imports a local media file and the project records real metadata such as duration, dimensions, frame rate, and stream presence instead of relying only on file extension defaults.

**Why this priority**: Real durations and dimensions are required before timeline clips, subtitles, thumbnails, preview, and later export can behave credibly.

**Independent Test**: Can be tested with deterministic parser/unit tests using representative `ffprobe` JSON plus an integration smoke path that handles unavailable probe tools.

**Acceptance Scenarios**:

1. **Given** a readable video file and a successful probe result, **When** the asset is probed, **Then** the project stores duration, dimensions, frame rate, and video/audio stream presence.
2. **Given** a readable audio-only file and a successful probe result, **When** the asset is probed, **Then** the project stores duration and audio stream presence without inventing video dimensions.
3. **Given** `ffprobe` is missing or returns invalid output, **When** the asset is probed, **Then** the project keeps the asset importable and records a clear probe status instead of crashing.

---

### User Story 2 - Persist And Surface Probe Results (Priority: P1)

A creator saves and reloads a project after probing media and sees the same metadata in the Library and CLI inspection views.

**Why this priority**: Probe work is too expensive and too important to disappear on save/load.

**Independent Test**: Can be tested by assigning probe metadata to assets, saving project JSON, loading it, and comparing metadata fields and status.

**Acceptance Scenarios**:

1. **Given** an asset has successful probe metadata, **When** the project is saved and loaded, **Then** duration, dimensions, frame rate, stream flags, and probe status survive.
2. **Given** a project from a prior schema-1 mission lacks probe metadata fields, **When** it is loaded, **Then** it remains loadable with unknown/unprobed metadata defaults.
3. **Given** a probed asset becomes missing on disk later, **When** the project is loaded, **Then** missing/offline media status remains explicit and persisted probe metadata is not silently discarded.

---

### User Story 3 - Expose Probe Metadata Across The C ABI (Priority: P1)

The Qt shell can display probe metadata without parsing Zig internals or reaching around the C ABI boundary.

**Why this priority**: The existing UI reads asset summaries through the ABI; probe metadata must follow the same ownership model.

**Independent Test**: Can be tested by creating a project, assigning probe metadata, reading asset summaries or dedicated probe summaries through C ABI buffers, and checking status behavior.

**Acceptance Scenarios**:

1. **Given** an asset has probe metadata, **When** Qt requests an asset summary, **Then** the summary includes human-usable duration, dimensions, frame rate, and stream presence fields or a dedicated probe summary exposes them.
2. **Given** an asset has not been probed, **When** Qt requests probe information, **Then** the ABI returns an explicit unprobed status or fields marked unknown.
3. **Given** a caller supplies a too-small buffer, **When** probe metadata is requested, **Then** the ABI uses the existing caller-owned buffer pattern and returns `PONTIFICATE_STATUS_BUFFER_TOO_SMALL`.

---

### User Story 4 - Add First-Pass Preview Surface (Priority: P2)

A creator can select a Library asset or timeline clip and see a still preview instead of an empty placeholder panel.

**Why this priority**: A video editor starts to feel real when selecting media changes what the creator can see, even before full playback exists.

**Independent Test**: Can be tested by launching Qt, importing a still image or video, selecting it, requesting preview, and confirming the preview panel updates or reports a clear unavailable state.

**Acceptance Scenarios**:

1. **Given** a selected still image asset, **When** the preview is refreshed, **Then** the preview panel displays the image scaled to fit without changing project state.
2. **Given** a selected video asset and `ffmpeg` can extract a frame, **When** the preview is refreshed at a requested time, **Then** the preview panel displays the extracted frame.
3. **Given** frame extraction fails or the media is offline, **When** preview is requested, **Then** the preview panel and status bar report the failure clearly and no invalid project mutation occurs.

---

### User Story 5 - Keep Timeline Durations Honest Enough For Editing (Priority: P2)

A creator adds a probed asset to the timeline and gets a default clip duration based on real metadata when available.

**Why this priority**: Timeline editing becomes more useful when clip lengths represent the source rather than a fixed extension-based fallback.

**Independent Test**: Can be tested by adding a probed asset to the timeline and checking clip duration, then repeating with unprobed/offline assets to ensure existing fallbacks still work.

**Acceptance Scenarios**:

1. **Given** a probed video asset has a known duration, **When** it is added to the timeline without an explicit placement duration, **Then** the clip duration uses the probed duration.
2. **Given** a still image asset has no intrinsic duration, **When** it is added to the timeline, **Then** existing still-image duration fallback remains stable.
3. **Given** an asset has no probe metadata, **When** it is added to the timeline, **Then** existing default duration behavior remains unchanged.

### Edge Cases

- `ffprobe` or `ffmpeg` may be missing.
- Probe output may be malformed, incomplete, or report `N/A`.
- Media paths may contain spaces, quotes, Unicode, or shell-sensitive characters.
- Audio-only files must not produce fake video dimensions.
- Still images may have dimensions but no duration.
- Subtitle files should remain importable but do not need probe metadata.
- Offline/missing media must remain loadable and visible.
- Preview frame extraction must not overwrite user media or require a persistent cache.
- Existing project files from previous missions must keep loading.
- The Qt shell must still launch with an empty project and with no FFmpeg tools installed.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Probe adapter | As a developer, I want a media probe adapter that can parse `ffprobe` JSON into typed project metadata so that broad Linux codec support can begin behind a small boundary. | High | Open |
| FR-002 | Probe statuses | As a creator, I want probe failures, missing tools, and unprobed assets reported explicitly so that the app never pretends metadata is known. | High | Open |
| FR-003 | Asset metadata model | As a developer, I want assets to store duration, dimensions, frame rate, stream presence, and probe status so that later timeline, thumbnail, subtitle, and export work can reuse one model. | High | Open |
| FR-004 | Project persistence | As a creator, I want probed metadata saved and loaded with the project so that import/probe work survives sessions. | High | Open |
| FR-005 | Backward-compatible project load | As a maintainer, I want prior schema-1 projects without probe fields to load with unknown defaults so that existing project files keep working. | High | Open |
| FR-006 | ABI probe surface | As a UI developer, I want probe metadata exposed through the C ABI using caller-owned buffers or summaries so that Qt can display it safely. | High | Open |
| FR-007 | CLI probe inspection | As a developer, I want CLI inspection to show probe metadata and probe status so that validation can run headlessly. | Medium | Open |
| FR-008 | Qt library metadata display | As a creator, I want the Library panel to show duration/dimensions/frame rate when available so that imported media is understandable. | Medium | Open |
| FR-009 | Still-image preview | As a creator, I want selected still images to appear in the preview panel so that image assets are inspectable. | Medium | Open |
| FR-010 | Video frame preview | As a creator, I want a selected video to show a representative extracted frame when FFmpeg is available so that timeline/media selection has visual feedback. | Medium | Open |
| FR-011 | Preview failure feedback | As a creator, I want preview failures to be visible in the UI status area so that missing tools or offline media are not silent. | Medium | Open |
| FR-012 | Probed timeline duration | As a creator, I want added video/audio clips to use probed source duration when available so that timeline placement is more honest. | Medium | Open |
| FR-013 | Documentation update | As a maintainer, I want docs to explain probe/preview capability and non-goals so that playback/export/color/subtitle expectations stay honest. | Low | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Deterministic parser tests | Probe parsing, metadata defaults, persistence, and failure mapping must be covered by `zig build test` without requiring real media files. | Reliability | High | Open |
| NFR-002 | Build continuity | `zig build test`, `zig build run`, `cmake -S . -B build`, and `cmake --build build` must pass after the mission. | Reliability | High | Open |
| NFR-003 | Tool absence tolerance | Missing `ffprobe` or `ffmpeg` must produce explicit unavailable statuses and must not prevent import, save/load, or Qt launch. | Reliability | High | Open |
| NFR-004 | Safe process execution | External command invocation must avoid shell interpolation and pass paths as arguments so shell-sensitive paths are safe. | Security | High | Open |
| NFR-005 | Linux-first UX | The Qt shell remains the Linux-first desktop target and should display degraded states clearly when optional media tools are unavailable. | Compatibility | High | Open |
| NFR-006 | Responsive UI path | Basic selection, redraw, and edit controls must remain usable; probe/preview work should happen only on explicit import/refresh actions or small controlled calls in this first pass. | Performance | Medium | Open |
| NFR-007 | No persistent media cache | This mission must not introduce long-lived thumbnail/proxy/render-cache directories. Temporary preview frames are allowed only if cleaned or scoped safely. | Maintainability | Medium | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | Zig project ownership | Asset metadata, probe status, persistence, and summaries belong in the Zig core/project model. | Technical | High | Open |
| C-002 | Process boundary allowed | `ffprobe` and `ffmpeg` may be invoked as external tools for this mission; direct FFmpeg library binding is not required yet. | Technical | High | Open |
| C-003 | Qt 5 shell | The current Qt 5 Widgets shell remains the UI target for preview and metadata display. | Technical | High | Open |
| C-004 | C ABI boundary | Qt must continue to call through `core/include/pontificate_core.h` or an equally explicit C ABI boundary for project-owned metadata. | Technical | High | Open |
| C-005 | No real-time playback | Continuous playback, audio sync, transport clocks, scrubbing engine, and frame-accurate seeking are out of scope. | Scope | High | Open |
| C-006 | No render/export | Export, render graph execution, transcode queues, and codec selection UI are out of scope. | Scope | High | Open |
| C-007 | No waveform/thumbnail cache | Waveform generation, thumbnail strips, proxy files, render cache, and cache invalidation are out of scope. | Scope | Medium | Open |
| C-008 | No color processing | Scopes, LUTs, color management, GPU color transforms, and darkroom processing remain out of scope except that preview should not block future color work. | Scope | Medium | Open |
| C-009 | No subtitle editor | Subtitle import/export, text editing, Whisper, style editing, and font handling remain out of scope. | Scope | Medium | Open |
| C-010 | Public repo hygiene | Generated local agent payloads, extracted temporary preview files, and temporary worktrees must remain ignored and must not be published. | Security | High | Open |

### Key Entities *(include if feature involves data)*

- **MediaProbe**: A bounded operation that inspects a media path and returns metadata or an explicit unavailable/error status.
- **ProbeStatus**: The state of probe metadata for an asset: unprobed, available, unavailable tool, failed, malformed, or unsupported.
- **MediaMetadata**: Optional duration, dimensions, frame rate, audio/video/subtitle stream presence, and display-safe codec/container labels.
- **PreviewFrame**: A temporary image generated from a still asset or video frame request for display in Qt.
- **PreviewRequest**: A UI-level request for an asset or clip preview at a selected time.
- **ProjectFile**: The JSON project representation. It must persist probe metadata while loading older schema-1 files without those fields.
- **MediaAsset**: The existing asset record extended with probe status and metadata.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `zig build test` covers parsing representative `ffprobe` JSON for video, audio-only, still-image-like, malformed, and missing-field cases.
- **SC-002**: Project JSON round-trip preserves probe status, duration, dimensions, frame rate, and stream presence.
- **SC-003**: Older schema-1 project JSON without probe metadata loads successfully with unprobed/unknown defaults.
- **SC-004**: C ABI summaries expose probe metadata or explicit unknown/unavailable status without returning Zig-owned memory.
- **SC-005**: CLI inspection displays probe status and known metadata for assets.
- **SC-006**: Qt Library rows display known duration/dimensions/frame rate when present.
- **SC-007**: Qt preview panel can show a selected still image in an offscreen-launchable build.
- **SC-008**: Qt preview path reports a clear unavailable/failure message when frame extraction is unavailable.
- **SC-009**: Adding a probed video/audio asset to the timeline uses the probed duration by default.
- **SC-010**: Validation commands pass: `zig build test`, `zig build run`, `cmake -S . -B build`, `cmake --build build`, and `git diff --check`.
- **SC-011**: Public docs distinguish shipped probe/preview behavior from non-shipped playback, export, proxy/cache, waveform, color, and subtitle workflows.

## Out Of Scope

- Real-time playback, transport clock, audio sync, and scrub engine.
- Render/export, transcode queues, render graph execution, and codec preset UI.
- Thumbnail strips, waveform generation, proxy generation, persistent cache directories, and cache invalidation.
- Color scopes, LUTs, color management, GPU color transforms, and darkroom grading controls.
- Subtitle import/export, Whisper transcription, text editing, style editing, and font workflows.
- Full native FFmpeg/GStreamer library integration.
- Packaged distribution changes.

## Open Questions For Planning

- Should probing run automatically during import, through an explicit "Probe" action, or both?
- Should first-pass video preview extract a frame to a temporary file or stream bytes into Qt directly?
- Should the core store codec/container labels now, or only duration/dimensions/frame rate/stream flags?
- Should probed duration immediately update existing clips from that asset, or only new clips created after probing?
- How should UI progress/cancel behavior work if a probe or preview command is slow?
