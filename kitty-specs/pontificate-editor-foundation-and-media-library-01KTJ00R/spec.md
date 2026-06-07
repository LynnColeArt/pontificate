# Mission Specification: Pontificate Editor Foundation And Media Library

**Mission Branch**: `kitty/mission-pontificate-editor-foundation-and-media-library-01KTJ00R`
**Created**: 2026-06-07
**Status**: Draft
**Input**: User description: "Keep going with Pontificate using Spec Kitty. Start the first software-development mission for the Linux-first Zig core plus Qt shell video editor, focused on making the current scaffold into a real editor foundation with media library behavior."

## Product Context

Pontificate is a Linux-first video editor with a Zig editing core and a Qt desktop shell. The long-term product aims to be approachable like consumer editors while taking subtitles, darkroom-style color work, timeline zoom, reliability, and packaging seriously.

This mission is not the whole video editor. It is the first implementation foundation mission after the initial scaffold. The mission should replace hardcoded starter data with real project and media-library state, establish enough timeline data flow for later editing features, and keep the Zig/Qt boundary testable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import Media Into A Real Library (Priority: P1)

A Linux creator opens Pontificate and imports local media files into the project library. The library shows useful rows instead of the current hardcoded placeholder list.

**Why this priority**: A video editor without a real media library cannot move beyond a mock shell. Importing media is the first concrete user action that anchors the editor.

**Independent Test**: Can be tested by launching the Qt app, choosing an import command, selecting one or more local files, and seeing the library populate with file-backed asset entries.

**Acceptance Scenarios**:

1. **Given** the app is open with an empty project, **When** the user imports one supported local media file, **Then** the Library panel shows an asset row with at least display name, media kind, source path, and availability status.
2. **Given** the app is open, **When** the user imports multiple files in one action, **Then** all accepted files appear in the Library panel without replacing earlier imported assets.
3. **Given** the user imports the same path twice, **When** the second import completes, **Then** the project avoids duplicate assets or clearly reports that the asset already exists.

---

### User Story 2 - Preserve Project State Across Sessions (Priority: P1)

A creator can save the project after importing media and reopen it later with the same library state restored.

**Why this priority**: Reliable project state is the foundation for autosave, relinking, timelines, subtitles, and future render/export work.

**Independent Test**: Can be tested by importing media, saving a project file, closing the app, reopening or loading through a headless/core path, and verifying that the assets are still present.

**Acceptance Scenarios**:

1. **Given** a project contains imported media assets, **When** the project is saved, **Then** the project file records asset IDs, display names, source paths, media kinds, and availability metadata.
2. **Given** a saved project file exists, **When** it is loaded, **Then** the core reconstructs the media library with stable asset IDs and no loss of imported asset rows.
3. **Given** a project file references a file that no longer exists, **When** the project is loaded, **Then** the asset remains in the library with an offline/missing status instead of being silently dropped.

---

### User Story 3 - Build Timeline State From Library Assets (Priority: P2)

A creator can place imported library assets into initial timeline state so the timeline becomes data-driven rather than a static drawing.

**Why this priority**: Timeline editing is Pontificate's main workflow. This mission should create the model bridge from media library to timeline without trying to implement all trim/ripple tools.

**Independent Test**: Can be tested by importing media, adding one asset to the timeline, and verifying that both the Zig core and Qt timeline view reflect the asset-backed clip.

**Acceptance Scenarios**:

1. **Given** an imported video asset exists, **When** the user adds it to the timeline, **Then** the timeline model contains a clip referencing that asset ID.
2. **Given** the timeline contains asset-backed clips, **When** the timeline is rendered in the Qt shell, **Then** clip labels and rough durations come from project state rather than hardcoded UI literals.
3. **Given** the timeline zoom control is used, **When** the timeline contains data-driven clips, **Then** zoom still scales the timeline horizontally without losing clip selection or labels.

---

### User Story 4 - Validate The Core/UI Boundary (Priority: P2)

A developer can evolve the editor safely because the Zig core owns deterministic project state and Qt consumes it through a documented boundary.

**Why this priority**: The app is intentionally split into a native core and rich desktop shell. That split must stay practical before more features land.

**Independent Test**: Can be tested by running core unit tests, the core CLI, and the Qt build after changes to media-library and project-state behavior.

**Acceptance Scenarios**:

1. **Given** project/media-library code changes, **When** `zig build test` runs, **Then** core project, asset import, duplicate handling, and missing-file tests pass.
2. **Given** the Qt app links against the Zig core, **When** `cmake --build build` runs, **Then** the app builds without requiring generated files outside the repo.
3. **Given** a developer inspects the C ABI header, **When** they look for project/media-library functions, **Then** the available boundary functions are named and documented enough for the Qt caller to use without reaching into Zig internals.

### Edge Cases

- Importing a file path that does not exist must produce a rejected import result or offline asset state; it must not crash the app.
- Importing directories is out of scope unless the UI deliberately filters them out.
- Unknown file extensions should be classified as unknown/other or rejected with a visible status; they must not be misclassified as video.
- Duplicate imports should be deterministic by normalized path.
- Project load must tolerate missing source media and preserve the asset record for later relinking.
- Project file parsing errors must produce a clear failure path in the core CLI or tests.
- File paths may contain spaces and non-project-relative locations.
- The Qt app must continue to launch when the project is empty.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Media asset model | As a creator, I want imported files represented as media assets with stable IDs, names, paths, kinds, and status so that the project library is real data. | High | Open |
| FR-002 | Library import action | As a creator, I want to import one or more local files from the Qt shell so that I can start an edit from my filesystem. | High | Open |
| FR-003 | Duplicate import handling | As a creator, I want duplicate imports handled predictably so that my library does not fill with repeated entries. | High | Open |
| FR-004 | Missing media status | As a creator, I want missing media to remain visible as offline assets so that projects can be repaired later. | High | Open |
| FR-005 | Project save/load | As a creator, I want project state saved and loaded with media-library data so that imported assets survive app restarts. | High | Open |
| FR-006 | Data-driven library UI | As a creator, I want the Library panel to render project assets instead of hardcoded demo items so that the UI reflects my project. | High | Open |
| FR-007 | Asset-backed timeline clip | As a creator, I want to add an imported asset to initial timeline state so that the timeline can evolve from real media. | Medium | Open |
| FR-008 | Data-driven timeline rendering | As a creator, I want the timeline view to render clips from core/project state while preserving timeline zoom behavior. | Medium | Open |
| FR-009 | Core CLI project inspection | As a developer, I want a CLI path that can summarize project/library state so that headless validation does not depend on Qt. | Medium | Open |
| FR-010 | C ABI media-library boundary | As a developer, I want Qt-facing C ABI functions for library counts and asset summaries so that the UI boundary stays explicit. | Medium | Open |
| FR-011 | Validation documentation | As a maintainer, I want README or architecture notes updated for project/media-library behavior so that future work starts from the right model. | Low | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Core determinism | Core import, duplicate, save/load, and missing-media behavior must be covered by `zig build test`. | Reliability | High | Open |
| NFR-002 | Build continuity | `zig build test`, `zig build run`, `cmake -S . -B build`, and `cmake --build build` must pass after the mission. | Reliability | High | Open |
| NFR-003 | Launch speed guard | The Qt shell must still open without importing media or loading a project file; empty-project startup must not depend on external media tools. | Performance | Medium | Open |
| NFR-004 | Clear failure states | Import/load failures must be represented as explicit results, statuses, or messages; they must not crash the app in normal user flows. | Reliability | High | Open |
| NFR-005 | Linux filesystem fit | File handling must work with absolute paths and paths containing spaces on Linux. | Compatibility | High | Open |
| NFR-006 | Small scope | The mission must not introduce heavyweight playback/export dependencies unless they are only documented for future integration. | Maintainability | High | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | Zig core ownership | Project state, media-library state, timeline references, and import classification belong in the Zig core, not only in Qt widgets. | Technical | High | Open |
| C-002 | Qt 5 shell | The current Qt 5 Widgets shell remains the UI target for this mission. | Technical | High | Open |
| C-003 | C ABI boundary | Qt must continue to link through `core/include/pontificate_core.h` or a similarly explicit boundary; Qt must not parse Zig source or depend on Zig internals. | Technical | High | Open |
| C-004 | No full media engine yet | Real decoding, playback synchronization, export rendering, proxies, waveform generation, and thumbnails are out of scope for this mission. | Scope | High | Open |
| C-005 | No color darkroom yet | Darkroom color controls, scopes, LUTs, and color-management implementation are out of scope except for preserving architectural space. | Scope | Medium | Open |
| C-006 | No Whisper/subtitle generation yet | Whisper integration and subtitle import/export are out of scope except for not blocking the existing subtitle model. | Scope | Medium | Open |
| C-007 | No packaging work yet | Flatpak, Snap, and portable executable packaging are out of scope for this mission. | Scope | Medium | Open |
| C-008 | Public repo hygiene | Generated local agent skill payloads under `.agents/skills/` must remain ignored and must not be published. | Security | High | Open |

### Key Entities *(include if feature involves data)*

- **Project**: The top-level editable document. It owns a project ID/version, media library, timeline tracks, clips, and future style/color/export settings.
- **MediaAsset**: A source file known to the project. Key attributes include stable ID, display name, source path, media kind, availability status, optional duration, optional dimensions, and import timestamp or ordering.
- **MediaKind**: Classification for imported assets such as video, audio, image, subtitle, unknown, or other. Early classification may use file extensions until FFmpeg probing lands.
- **MediaStatus**: Whether an asset is available, missing/offline, duplicate/rejected, or unsupported.
- **TimelineTrack**: A track with kind and display name. This mission can keep the existing video/audio/subtitle/adjustment track shape.
- **TimelineClip**: A timeline item referencing a MediaAsset ID plus timeline start, source in, duration, opacity/keyframe data, and blend mode where applicable.
- **ProjectFile**: A serialized representation of project state with schema versioning so future migrations are possible.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can import at least three local files in one Qt action and see three corresponding Library rows with file-backed data.
- **SC-002**: Saving and loading a project preserves 100% of imported asset IDs, display names, paths, kinds, and availability statuses in core tests.
- **SC-003**: Loading a project with at least one missing file preserves the offline asset record and reports missing status instead of dropping it.
- **SC-004**: A data-driven timeline clip can be created from an imported asset and displayed in the Qt timeline while timeline zoom remains functional.
- **SC-005**: The current validation commands pass: `zig build test`, `zig build run`, `cmake -S . -B build`, and `cmake --build build`.
- **SC-006**: The Library panel no longer depends on the hardcoded starter item list for normal project display.
- **SC-007**: The mission leaves clear documented non-goals for playback, export, color darkroom, subtitles/Whisper, proxies, thumbnails, and packaging.

## Out Of Scope

- Frame-accurate playback and audio/video sync.
- Actual decoding/probing through FFmpeg or GStreamer beyond possible future-facing abstractions.
- Thumbnail generation and waveform generation.
- Export/render queue behavior.
- Subtitle import/export and Whisper transcription.
- Color grading implementation, scopes, LUTs, and OpenColorIO/libplacebo integration.
- Proxy generation, render cache, and performance cache invalidation.
- Drag-and-drop polish beyond a minimal add-to-timeline path if the plan chooses one.
- Flatpak, Snap, or direct-executable release packaging.

## Open Questions For Planning

- Should the first project file format be JSON, Zig ZON, or another simple text format?
- Should the C ABI expose full asset records immediately, or should Qt call coarse summary functions until a stable handle model exists?
- Should imported media be copied into the project directory later, or should Pontificate remain reference-based by default?
- Should first-pass media kind classification be extension-only, or should the mission add a minimal optional probe abstraction without depending on FFmpeg yet?
