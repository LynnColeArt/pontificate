# Mission Specification: Timeline Editing And Keyframe Engine

**Mission Branch**: `kitty/mission-timeline-editing-and-keyframe-engine-01KTJVYN`
**Created**: 2026-06-08
**Status**: Draft
**Input**: User direction: "Push the completed foundation mission, then start the next mission. Use timeline/keyframes as the next conservative default because that becomes the spine for transitions, subtitles, blend modes, and color work."

## Product Context

Pontificate is a Linux-first Zig core plus Qt desktop video editor. The first implementation mission established real media-library/project state, a C ABI boundary, project save/load, and a data-driven timeline display.

This mission turns that foundation into the first useful editing surface. It should introduce deterministic timeline edit operations and a general keyframe model that future missions can reuse for transitions, subtitles, blend modes, transform animation, and darkroom-style color grading. The mission must still avoid pretending to be a complete nonlinear editor: frame decoding, playback synchronization, rendering/export, waveform generation, thumbnails, advanced ripple editing, and color-processing internals remain future work.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cut And Trim Timeline Clips (Priority: P1)

A creator can split an asset-backed clip at a playhead position, then trim clip in/out points without corrupting source timing or creating invalid durations.

**Why this priority**: Cutting and trimming are the smallest credible editing actions after importing media into a timeline.

**Independent Test**: Can be tested through Zig core tests and a CLI inspection path by creating a project, adding an asset-backed clip, splitting it, trimming one side, and verifying resulting clip summaries.

**Acceptance Scenarios**:

1. **Given** a timeline clip from 0.0s to 5.0s, **When** the clip is split at 2.0s, **Then** the timeline contains two clips with contiguous timeline spans and correct source in-points.
2. **Given** a selected clip, **When** its start trim is moved later, **Then** the clip timeline start and source in-point advance while duration remains positive.
3. **Given** a trim or split would create a zero or negative duration clip, **When** the operation is requested, **Then** the core rejects the edit with an explicit error and leaves the timeline unchanged.

---

### User Story 2 - Move Clips On Layered Tracks (Priority: P1)

A creator can move clips along the timeline and between compatible tracks while the core preserves deterministic ordering and rejects invalid placements.

**Why this priority**: Layered editing is central to the product promise, and later transitions, subtitles, and grade layers depend on stable clip placement semantics.

**Independent Test**: Can be tested by moving clips across default video/audio/subtitle/grade tracks and inspecting track IDs, track indexes, timeline starts, and sorted clip order.

**Acceptance Scenarios**:

1. **Given** a video clip exists on `V1`, **When** it is moved later on the same track, **Then** its timeline start changes and project save/load preserves the new position.
2. **Given** a clip move targets an incompatible track kind, **When** the operation is requested, **Then** the core rejects the move with an explicit error.
3. **Given** multiple clips exist, **When** edits are applied, **Then** timeline summaries are sorted predictably by track and time for UI rendering.

---

### User Story 3 - Add And Evaluate Keyframes (Priority: P1)

A creator or future editor tool can add keyframes to a clip property and evaluate the property at an arbitrary timeline time.

**Why this priority**: Keyframes are the shared mechanism for opacity fades, transform animation, subtitle styling, transition parameters, and color adjustments.

**Independent Test**: Can be tested in `zig build test` by assigning keyframes to opacity and transform-like properties, then evaluating values before, between, and after keyframes.

**Acceptance Scenarios**:

1. **Given** a clip has opacity keyframes at 0.0s and 1.0s, **When** opacity is evaluated at 0.5s, **Then** the core returns an interpolated value.
2. **Given** keyframes are inserted out of order, **When** the clip is summarized or saved, **Then** keyframes are stored and emitted in deterministic time order.
3. **Given** an unsupported keyframe property is requested through the public model, **When** the operation is attempted, **Then** the core rejects it without corrupting existing keyframes.

---

### User Story 4 - Preserve Timeline Editing Through Project Save/Load (Priority: P2)

A creator can save a project after timeline edits and keyframe authoring, then reload it with the same clip placements and animation data.

**Why this priority**: Timeline edits must be durable before the UI can safely add more controls.

**Independent Test**: Can be tested by writing a project to JSON, reloading it, and comparing clip spans, track assignment, blend mode, opacity, and keyframe data.

**Acceptance Scenarios**:

1. **Given** a project has split and moved clips, **When** it is saved and loaded, **Then** clip IDs, asset IDs, track IDs, timeline starts, source in-points, durations, opacity, and blend mode survive.
2. **Given** a project has keyframes, **When** it is saved and loaded, **Then** the keyframes can still be evaluated at the same times with the same results.
3. **Given** an older schema-1 project without keyframe arrays is loaded, **When** the loader reads it, **Then** existing projects remain loadable with sensible default keyframe state.

---

### User Story 5 - Expose Editing Actions In The Qt Timeline Shell (Priority: P2)

A creator can use the Qt shell for first-pass editing actions without requiring direct Zig CLI calls.

**Why this priority**: Pontificate should feel like an app, not only a core library, even while the editing surface remains early.

**Independent Test**: Can be tested by launching the Qt app, importing media, adding it to the timeline, selecting a clip, using toolbar/menu actions for split/trim/move basics, and seeing the timeline redraw without losing zoom.

**Acceptance Scenarios**:

1. **Given** a clip is selected in the timeline, **When** the user triggers a split action at a chosen time, **Then** the timeline redraws with two clips and the library remains unchanged.
2. **Given** timeline zoom is changed, **When** edit actions redraw clips, **Then** zoom remains applied and labels stay readable enough for the current placeholder display.
3. **Given** a core edit operation fails, **When** the Qt shell receives the failure, **Then** the status bar reports a clear message instead of silently doing nothing.

### Edge Cases

- Splitting at or outside clip boundaries must be rejected.
- Trimming past the opposite edge must be rejected.
- Moving a clip to a negative timeline start must be rejected.
- Moving media to an incompatible track must be rejected unless the core explicitly supports that media kind on the target track.
- Keyframe times must be finite and non-negative within clip-local time.
- Duplicate keyframes for a property/time should replace the existing value or be rejected consistently; the choice must be documented by implementation tests.
- Project loading must tolerate schema-1 project files that lack keyframe data.
- Timeline zoom and redraw must not depend on imported media files still existing on disk.
- The Qt shell must continue to launch with an empty project.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Clip split operation | As a creator, I want to split a clip at a timeline time so that I can make cuts without manual re-imports. | High | Open |
| FR-002 | Clip trim operation | As a creator, I want to trim clip starts and ends so that I can choose usable ranges. | High | Open |
| FR-003 | Clip move operation | As a creator, I want to move clips along and between compatible tracks so that I can layer edits. | High | Open |
| FR-004 | Timeline ordering | As a creator, I want clips summarized in deterministic track/time order so that the UI redraws predictably. | High | Open |
| FR-005 | Compatibility validation | As a creator, I want invalid track placements rejected clearly so that timeline state stays coherent. | High | Open |
| FR-006 | General keyframe model | As a creator, I want clip properties to support time/value keyframes so that fades and future animation share one system. | High | Open |
| FR-007 | Keyframe interpolation | As a creator, I want keyframed values evaluated between points so that animation can be previewed and later rendered. | High | Open |
| FR-008 | Keyframe persistence | As a creator, I want keyframes saved and loaded with projects so that animation work survives sessions. | High | Open |
| FR-009 | Backward-compatible project load | As a maintainer, I want schema-1 project files without keyframes to load so that the previous mission's projects remain usable. | Medium | Open |
| FR-010 | C ABI editing boundary | As a developer, I want Qt-facing C ABI functions for split, trim, move, and keyframe summary/evaluation so that the shell does not reach into Zig internals. | Medium | Open |
| FR-011 | Qt editing affordances | As a creator, I want initial Qt controls for split/trim/move basics so that timeline editing can be exercised visually. | Medium | Open |
| FR-012 | CLI validation path | As a developer, I want headless project/timeline inspection to cover edits and keyframes so that validation does not depend only on Qt. | Medium | Open |
| FR-013 | Documentation update | As a maintainer, I want architecture notes updated for timeline operations and keyframes so that later transition/color/subtitle missions reuse the same model. | Low | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Deterministic core edits | Split, trim, move, ordering, keyframe insert, keyframe replace, and keyframe evaluation behavior must be covered by `zig build test`. | Reliability | High | Open |
| NFR-002 | Build continuity | `zig build test`, `zig build run`, `cmake -S . -B build`, and `cmake --build build` must pass after the mission. | Reliability | High | Open |
| NFR-003 | Explicit failures | Invalid edit requests must return explicit core/C ABI statuses and must not partially mutate project state. | Reliability | High | Open |
| NFR-004 | Linux-first UX | The Qt shell remains the Linux-first desktop target and must continue to launch without platform-specific assumptions. | Compatibility | High | Open |
| NFR-005 | Small media footprint | The mission must not add decoder, playback, render, thumbnail, proxy, waveform, or GPU dependencies. | Maintainability | High | Open |
| NFR-006 | Responsive redraw | Placeholder timeline redraw for small projects should remain immediate enough for interactive editing; no operation in the basic Qt path should perform blocking media probing. | Performance | Medium | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | Zig core ownership | Timeline edit operations, validation, keyframes, persistence, and summaries belong in the Zig core. | Technical | High | Open |
| C-002 | Qt 5 shell | The current Qt 5 Widgets shell remains the UI target for this mission. | Technical | High | Open |
| C-003 | C ABI boundary | Qt must continue to call through `core/include/pontificate_core.h` or an equally explicit C ABI boundary. | Technical | High | Open |
| C-004 | No playback engine | Frame-accurate playback, decoding, scrubbing preview, audio sync, and rendering/export are out of scope. | Scope | High | Open |
| C-005 | No full transition system | Transition UI and transition rendering are out of scope except for keyframe architecture that can support them later. | Scope | Medium | Open |
| C-006 | No color darkroom yet | Scopes, LUTs, color management, GPU color processing, and color-room UI are out of scope except for reusable keyframe semantics. | Scope | Medium | Open |
| C-007 | No subtitle editor yet | Subtitle import/export, Whisper, and subtitle text/style editing are out of scope except for preserving subtitle-track compatibility. | Scope | Medium | Open |
| C-008 | Public repo hygiene | Generated local agent payloads and temporary worktrees must remain ignored and must not be published. | Security | High | Open |

### Key Entities *(include if feature involves data)*

- **TimelineClip**: A placed segment that references a media asset and owns track ID, timeline start, source in-point, duration, opacity, blend mode, and keyframes.
- **TimelineEdit**: A deterministic core operation such as split, trim, or move that validates inputs before mutating project state.
- **TimelineSpan**: The timeline interval occupied by a clip. It is derived from timeline start and duration.
- **TrackCompatibility**: The rules that decide whether a media kind can be placed on a track kind.
- **KeyframeProperty**: A supported animatable property such as opacity now, with space for transform/color/subtitle-style properties later.
- **KeyframeValue**: A typed value for a property. The first mission may support scalar values directly and reserve structured values for later properties.
- **KeyframeCurve**: Ordered keyframes for one property, with deterministic insertion/replacement and evaluation behavior.
- **ProjectFile**: The serialized project representation. It must preserve timeline edits and keyframes while continuing to load prior schema-1 files.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Splitting a 5-second clip at 2 seconds produces two valid clips with durations 2 seconds and 3 seconds and source in-points 0 seconds and 2 seconds in core tests.
- **SC-002**: Invalid split, trim, move, and keyframe operations are rejected without partial mutation in core tests.
- **SC-003**: Moving clips updates track/time placement and project save/load preserves the edited placements.
- **SC-004**: At least one scalar property, opacity, supports keyframe insert/replace, deterministic ordering, interpolation, and persistence.
- **SC-005**: The C ABI exposes enough edit/keyframe functions for Qt to request edits and redraw from core summaries.
- **SC-006**: The Qt shell exposes first-pass split/trim/move controls or menu actions and preserves timeline zoom after redraw.
- **SC-007**: Existing schema-1 project files from the previous mission load without requiring keyframe fields.
- **SC-008**: The validation commands pass: `zig build test`, `zig build run`, `cmake -S . -B build`, and `cmake --build build`.
- **SC-009**: Documentation explains the keyframe model as the future shared path for transitions, subtitle animation, blend modes, and darkroom color controls.

## Out Of Scope

- Playback, decode, scrub preview, audio/video synchronization, and frame-accurate rendering.
- Export, render queues, render cache, proxies, thumbnails, and waveforms.
- Full drag-and-drop editing, ripple/roll/slip/slide tools, snapping, markers, multicam, and nested sequences.
- Full transition authoring or transition rendering.
- Color grading scopes, LUTs, color-management implementation, GPU processing, and color-room UI.
- Subtitle import/export, Whisper transcription, subtitle text editing, and global/local font styling.
- Packaging through Flatpak, Snap, AppImage, or direct release artifacts.

## Open Questions For Planning

- Should the first keyframe value representation support only scalar floats, or should it include typed vectors now for transform/color future proofing?
- Should edit operations accept clip indexes, clip IDs, or both through the C ABI?
- Should timeline overlap be allowed on the same track for now, or should same-track overlaps be rejected until transition semantics exist?
- Should Qt expose split/trim/move through toolbar/menu controls, keyboard shortcuts, inspector fields, or a small combination of those in this first pass?
