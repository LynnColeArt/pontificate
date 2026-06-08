# Work Packages: media-probe-and-preview-foundation-01KTK4DY

Generated from `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, and `contracts/pontificate-core-probe-preview-c-abi.md`.

## Subtask Index

| ID | Description | WP | Parallel |
|----|-------------|----|----------|
| T001 | Add probe metadata value types and status enum. | WP01 | No |
| T002 | Add `core/src/probe.zig` parser boundary and result model. | WP01 | No |
| T003 | Parse successful video, audio-only, and missing-field `ffprobe` JSON fixtures. | WP01 | No |
| T004 | Map malformed, failed, unavailable, and unsupported outcomes. | WP01 | No |
| T005 | Add deterministic parser tests and keep existing media tests passing. | WP01 | No |
| T006 | Wire new module into `build.zig` test coverage. | WP01 | No |
| T007 | Persist probe status and metadata in project JSON. | WP02 | No |
| T008 | Load older schema-1 assets without probe fields using unprobed defaults. | WP02 | No |
| T009 | Add explicit project-level probe operation and safe `ffprobe` process invocation. | WP02 | No |
| T010 | Preserve metadata when media revalidation marks a path missing. | WP02 | No |
| T011 | Update timeline asset placement to use known positive probed duration. | WP02 | No |
| T012 | Extend CLI inspection or add probe CLI smoke output. | WP02 | No |
| T013 | Add C header declarations for probe operation and probe summary. | WP03 | No |
| T014 | Implement ABI status mapping for probe outcomes. | WP03 | No |
| T015 | Implement caller-owned probe summary buffer behavior. | WP03 | No |
| T016 | Add ABI-focused tests for summary and buffer-too-small behavior. | WP03 | No |
| T017 | Show probe metadata in Qt Library rows. | WP04 | No |
| T018 | Add explicit UI probe action and refresh status feedback. | WP04 | No |
| T019 | Display still-image previews through Qt image loading. | WP04 | Yes |
| T020 | Extract video preview frames with `QProcess` and temporary files. | WP04 | No |
| T021 | Report offline, unsupported, missing-tool, and extraction failures in the preview/status UI. | WP04 | No |
| T022 | Keep preview display-only and ensure CMake/Qt build still passes. | WP04 | No |
| T023 | Update public feature and architecture docs with shipped probe/preview behavior. | WP05 | No |
| T024 | Document non-goals: playback, export, caches, color, subtitles, packaging. | WP05 | No |
| T025 | Record validation commands and acceptance evidence. | WP05 | No |
| T026 | Run final validation and clean worktree state. | WP05 | No |

---

## Work Package WP01: Probe Parser And Metadata Model

**Dependencies**: None
**Requirement Refs**: FR-001, FR-002, FR-003, NFR-001, NFR-003, NFR-004, C-001, C-002
**Plan Concerns**: IC-01
**Owned Files**: `core/src/probe.zig`, `core/src/media.zig`, `build.zig`
**Prompt**: `tasks/WP01-probe-parser-and-metadata-model.md`

**Included subtasks**:

- [ ] T001 Add probe metadata value types and status enum. (WP01)
- [ ] T002 Add `core/src/probe.zig` parser boundary and result model. (WP01)
- [ ] T003 Parse successful video, audio-only, and missing-field `ffprobe` JSON fixtures. (WP01)
- [ ] T004 Map malformed, failed, unavailable, and unsupported outcomes. (WP01)
- [ ] T005 Add deterministic parser tests and keep existing media tests passing. (WP01)
- [ ] T006 Wire new module into `build.zig` test coverage. (WP01)

**Independent test**: `zig build test` covers probe parser fixtures and metadata defaults without requiring FFmpeg tools.

---

## Work Package WP02: Project Persistence Probe Execution And CLI

**Dependencies**: WP01
**Requirement Refs**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-007, FR-012, SC-002, SC-003, SC-005, SC-009, NFR-001, NFR-002, NFR-003, NFR-004, C-001, C-002
**Plan Concerns**: IC-02, IC-03
**Owned Files**: `core/src/project.zig`, `core/src/main.zig`, `core/src/media.zig`
**Prompt**: `tasks/WP02-project-persistence-probe-execution-and-cli.md`

**Included subtasks**:

- [ ] T007 Persist probe status and metadata in project JSON. (WP02)
- [ ] T008 Load older schema-1 assets without probe fields using unprobed defaults. (WP02)
- [ ] T009 Add explicit project-level probe operation and safe `ffprobe` process invocation. (WP02)
- [ ] T010 Preserve metadata when media revalidation marks a path missing. (WP02)
- [ ] T011 Update timeline asset placement to use known positive probed duration. (WP02)
- [ ] T012 Extend CLI inspection or add probe CLI smoke output. (WP02)

**Independent test**: Project JSON round trip preserves probe metadata; old project JSON loads; CLI output reports known and unknown probe states.

---

## Work Package WP03: C ABI Probe Boundary

**Dependencies**: WP02
**Requirement Refs**: FR-006, SC-004, NFR-002, C-004
**Plan Concerns**: IC-04
**Owned Files**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`
**Prompt**: `tasks/WP03-c-abi-probe-boundary.md`

**Included subtasks**:

- [ ] T013 Add C header declarations for probe operation and probe summary. (WP03)
- [ ] T014 Implement ABI status mapping for probe outcomes. (WP03)
- [ ] T015 Implement caller-owned probe summary buffer behavior. (WP03)
- [ ] T016 Add ABI-focused tests for summary and buffer-too-small behavior. (WP03)

**Independent test**: ABI calls return OK, unsupported/out-of-range, and buffer-too-small statuses while never returning Zig-owned allocations.

---

## Work Package WP04: Qt Metadata And Preview Surface

**Dependencies**: WP03
**Requirement Refs**: FR-008, FR-009, FR-010, FR-011, SC-006, SC-007, SC-008, NFR-005, NFR-006, NFR-007, C-003, C-004, C-010
**Plan Concerns**: IC-05
**Owned Files**: `ui/src/main.cpp`, `CMakeLists.txt`
**Prompt**: `tasks/WP04-qt-metadata-and-preview-surface.md`

**Included subtasks**:

- [ ] T017 Show probe metadata in Qt Library rows. (WP04)
- [ ] T018 Add explicit UI probe action and refresh status feedback. (WP04)
- [ ] T019 Display still-image previews through Qt image loading. (WP04)
- [ ] T020 Extract video preview frames with `QProcess` and temporary files. (WP04)
- [ ] T021 Report offline, unsupported, missing-tool, and extraction failures in the preview/status UI. (WP04)
- [ ] T022 Keep preview display-only and ensure CMake/Qt build still passes. (WP04)

**Independent test**: Qt build passes; manual or offscreen smoke can show still preview and unavailable video-preview feedback.

---

## Work Package WP05: Documentation Validation And Acceptance Notes

**Dependencies**: WP04
**Requirement Refs**: FR-013, SC-010, SC-011, NFR-002, C-005, C-006, C-007, C-008, C-009, C-010
**Plan Concerns**: IC-06
**Owned Files**: `README.md`, `docs/**`, `kitty-specs/media-probe-and-preview-foundation-01KTK4DY/**`
**Prompt**: `tasks/WP05-documentation-validation-and-acceptance-notes.md`

**Included subtasks**:

- [ ] T023 Update public feature and architecture docs with shipped probe/preview behavior. (WP05)
- [ ] T024 Document non-goals: playback, export, caches, color, subtitles, packaging. (WP05)
- [ ] T025 Record validation commands and acceptance evidence. (WP05)
- [ ] T026 Run final validation and clean worktree state. (WP05)

**Independent test**: Docs match shipped behavior; validation commands are run and recorded before acceptance.
