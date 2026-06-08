# Implementation Plan: Pontificate Editor Foundation And Media Library

**Branch**: `kitty/mission-pontificate-editor-foundation-and-media-library-01KTJ00R` | **Date**: 2026-06-07 | **Spec**: `kitty-specs/pontificate-editor-foundation-and-media-library-01KTJ00R/spec.md`
**Input**: Feature specification from `kitty-specs/pontificate-editor-foundation-and-media-library-01KTJ00R/spec.md`

## Summary

This mission turns the current Pontificate scaffold into a real editor foundation. The Zig core will own project state, media-library state, initial timeline references, import classification, duplicate handling, missing-media status, and project save/load. The Qt 5 shell will stop relying on hardcoded library/timeline rows for normal display and will call the Zig core through an explicit C ABI.

The mission deliberately avoids playback, export, thumbnails, waveform generation, proxies, color grading, subtitle import/export, Whisper, and Linux packaging. Those remain product commitments for later missions, but this mission creates the project and media foundation they need.

## Technical Context

**Language/Version**: Zig 0.16.0 for the editor core and C ABI; C++17 with Qt 5.15.13 for the desktop shell.
**Primary Dependencies**: Zig standard library, Qt5 Core/Gui/Widgets, CMake 3.28.3. No FFmpeg, GStreamer, libplacebo, OpenColorIO, Whisper, or font-shaping dependency is introduced in this mission.
**Storage**: Project files stored as local JSON with explicit schema version `1`. Media remains reference-based by absolute or user-selected source paths; files are not copied into a project bundle.
**Testing**: Zig unit tests for project/media/timeline behavior; core CLI smoke output; CMake/Qt build validation. Manual app smoke for import and timeline display is acceptable until UI automation exists.
**Target Platform**: Linux desktop.
**Project Type**: Native desktop application with a Zig static core library, C ABI header, Qt executable, and headless CLI.
**Performance Goals**: Empty-project app launch remains independent of external media tools. Importing 100 path-only assets should complete without media decoding and without noticeably blocking beyond filesystem existence checks.
**Constraints**: Zig core owns project state. Qt calls the core through `core/include/pontificate_core.h`. First-pass media classification is extension-based. Unsupported or missing files must produce explicit status instead of crashes.
**Scale/Scope**: First-mission foundation for small creator projects, not a production-grade NLE media database.

## Charter Check

No project charter is present yet. Scope is governed by the mission spec, `README.md`, `docs/FEATURES.md`, `docs/ARCHITECTURE.md`, and `docs/DISTRIBUTION.md`.

No charter violations are known. Re-check this section after a charter is introduced.

## Project Structure

### Documentation (this mission)

```
kitty-specs/pontificate-editor-foundation-and-media-library-01KTJ00R/
├── spec.md
├── plan.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── pontificate-core-c-abi.md
├── tasks.md
└── tasks/
```

### Source Code (repository root)

```
core/
├── include/
│   └── pontificate_core.h
└── src/
    ├── main.zig
    ├── pontificate.zig
    ├── project.zig
    ├── media.zig
    └── timeline.zig

ui/
└── src/
    └── main.cpp

docs/
├── ARCHITECTURE.md
├── DISTRIBUTION.md
└── FEATURES.md

CMakeLists.txt
build.zig
README.md
```

**Structure Decision**: Keep the existing single native application structure. Split Zig core behavior into focused modules while preserving the current `pontificate.zig` import/export surface. Keep Qt in `ui/src/main.cpp` until the UI grows enough to justify additional files.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Opaque C ABI project handle | Qt needs to mutate and read core-owned project state across calls. | Static summary functions would keep the UI mock-like and would not satisfy core ownership requirements. |
| JSON project file in first mission | Save/load is required for project state and missing-media behavior. | In-memory-only state would fail the persistence user story and delay schema decisions too long. |

## Architecture And Data Flow

1. Qt creates or loads a `PontificateProject` handle through the C ABI.
2. The user selects files through a Qt file dialog.
3. Qt passes each selected path to a core import function.
4. The Zig core normalizes the path enough for deterministic duplicate detection, classifies the asset by extension, checks availability, and records or rejects the asset.
5. Qt refreshes the Library panel from core-provided asset summary calls.
6. The user can add a selected imported asset to timeline state.
7. The Zig core creates a clip referencing the media asset ID and default track.
8. Qt refreshes the timeline view from core-provided clip summary calls while preserving existing timeline zoom controls.
9. Save/load uses the core project model and JSON serialization. Load marks missing source files as offline.

## Project File Decision

Use JSON for project files in this mission.

Reasons:

- Easy to inspect while the schema is still young.
- Supported directly by Zig standard-library JSON APIs.
- Friendly to future migration tests and issue reports.
- Avoids inventing a binary or database storage layer before the editor has enough shape.

The format must include:

- `schema_version`
- `project_id`
- `assets`
- `tracks`
- `clips`

The implementation should keep the format intentionally small. Future missions may move to a richer document model or bundle layout.

## C ABI Decision

Use an opaque project handle instead of exposing Zig structs.

Expected shape:

```c
typedef struct PontificateProject PontificateProject;

PontificateProject *pontificate_project_create(void);
void pontificate_project_destroy(PontificateProject *project);
uint32_t pontificate_project_import_path(PontificateProject *project, const char *path);
uint32_t pontificate_project_asset_count(const PontificateProject *project);
uint32_t pontificate_project_asset_summary(const PontificateProject *project, uint32_t index, char *buffer, uint32_t buffer_len);
uint32_t pontificate_project_add_asset_to_timeline(PontificateProject *project, uint32_t asset_index);
uint32_t pontificate_project_clip_count(const PontificateProject *project);
uint32_t pontificate_project_clip_summary(const PontificateProject *project, uint32_t index, char *buffer, uint32_t buffer_len);
uint32_t pontificate_project_save(const PontificateProject *project, const char *path);
PontificateProject *pontificate_project_load(const char *path);
```

The exact names may change during implementation, but the boundary must avoid returning caller-owned Zig allocations without a matching free function. Summary-buffer APIs are acceptable for this mission because they keep ownership simple and testable.

## Testing Strategy

- Add Zig unit tests for:
  - media kind classification
  - duplicate import detection
  - missing/offline asset status
  - project save/load round trip
  - timeline clip creation from imported assets
  - keyframe tests continuing to pass
- Add CLI smoke behavior that can summarize default or loaded project state.
- Build Qt through CMake after C ABI changes.
- Manually launch the Qt app for import and timeline smoke if a display is available.

Required final commands:

```sh
zig build test
zig build run
cmake -S . -B build
cmake --build build
git status --short --branch
```

## Risks

- Zig 0.16 APIs are still moving, especially IO, JSON, and collection APIs. Keep implementation small and test-driven.
- C ABI memory ownership can become unsafe if string lifetimes are unclear. Prefer caller-provided buffers or explicit free functions.
- Qt UI can drift into owning project state. Keep UI state as presentation and selection state; project data belongs in the core.
- Save/load can overgrow into a full persistence framework. Keep schema v1 minimal.
- Extension-based media classification is intentionally shallow. Document that real probing comes later.

## Implementation Concern Map

### IC-01 - Core Project And Media Model

- **Purpose**: Define core-owned project, media asset, media kind, media status, track, and clip structures.
- **Relevant requirements**: FR-001, FR-003, FR-004, FR-007, NFR-001, C-001
- **Affected surfaces**: `core/src/pontificate.zig`, `core/src/project.zig`, `core/src/media.zig`, `core/src/timeline.zig`
- **Sequencing/depends-on**: none
- **Risks**: Keep the model small enough for v1 while leaving obvious extension points for probing, bins, thumbnails, subtitles, and color work.

### IC-02 - Project Save/Load And Offline Status

- **Purpose**: Persist project state and restore it with missing-media awareness.
- **Relevant requirements**: FR-004, FR-005, FR-009, NFR-001, NFR-004, NFR-005
- **Affected surfaces**: `core/src/project.zig`, `core/src/main.zig`, tests in Zig core
- **Sequencing/depends-on**: IC-01
- **Risks**: JSON parsing/writing should not become a large abstraction before project format needs are clearer.

### IC-03 - C ABI Project Boundary

- **Purpose**: Expose project/media/timeline operations to Qt without leaking Zig internals or allocation ownership.
- **Relevant requirements**: FR-002, FR-006, FR-008, FR-010, NFR-004, C-003
- **Affected surfaces**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`, `CMakeLists.txt`
- **Sequencing/depends-on**: IC-01, IC-02
- **Risks**: Handle lifetime and string summary buffers must be documented and tested enough to avoid Qt-side use-after-free patterns.

### IC-04 - Qt Library Import And Display

- **Purpose**: Replace the hardcoded Library list with data read from the core and add an import action that records selected local files.
- **Relevant requirements**: FR-002, FR-003, FR-006, SC-001, SC-006
- **Affected surfaces**: `ui/src/main.cpp`, `README.md`
- **Sequencing/depends-on**: IC-03
- **Risks**: Keep UI additions simple; avoid building a full bin/search/thumbnail system in this mission.

### IC-05 - Asset-Backed Timeline Display

- **Purpose**: Allow an imported asset to become initial timeline state and render clips from core summaries while preserving zoom.
- **Relevant requirements**: FR-007, FR-008, SC-004
- **Affected surfaces**: `core/src/timeline.zig`, `core/include/pontificate_core.h`, `ui/src/main.cpp`
- **Sequencing/depends-on**: IC-01, IC-03, IC-04
- **Risks**: Do not accidentally implement trim/ripple/edit tools here; this is a data flow milestone.

### IC-06 - Documentation And Validation

- **Purpose**: Keep public docs and developer validation commands aligned with the new project/media-library behavior.
- **Relevant requirements**: FR-011, NFR-002, C-004, C-005, C-006, C-007, C-008
- **Affected surfaces**: `README.md`, `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, mission artifacts
- **Sequencing/depends-on**: IC-01 through IC-05
- **Risks**: Avoid overclaiming playback, export, color, subtitles, or packaging as implemented.
