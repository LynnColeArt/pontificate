# Implementation Plan: Timeline Editing And Keyframe Engine

**Branch**: `kitty/mission-timeline-editing-and-keyframe-engine-01KTJVYN` | **Date**: 2026-06-08 | **Spec**: `kitty-specs/timeline-editing-and-keyframe-engine-01KTJVYN/spec.md`
**Input**: Feature specification from `kitty-specs/timeline-editing-and-keyframe-engine-01KTJVYN/spec.md`

## Summary

This mission adds Pontificate's first real editing operations and a reusable keyframe engine. The Zig core will own clip split, trim, move, track compatibility, deterministic timeline ordering, keyframe storage, scalar keyframe interpolation, and project persistence. The C ABI will expose those operations to the Qt shell, and the Qt timeline will gain first-pass controls that redraw from core state while preserving timeline zoom.

The mission deliberately avoids playback, decoding, render/export, full drag editing, ripple/roll/slip/slide tools, transition rendering, color-room implementation, subtitle editing, Whisper, and packaging. The keyframe model is the architectural bridge to those future features, not a claim that they are implemented here.

## Technical Context

**Language/Version**: Zig 0.16.0 for the core and C ABI; C++17 with Qt 5.15.13 for the desktop shell.
**Primary Dependencies**: Zig standard library, Qt5 Core/Gui/Widgets, CMake 3.28.3. No FFmpeg, GStreamer, libplacebo, OpenColorIO, Whisper, font-shaping, GPU, or render dependencies are introduced.
**Storage**: Local JSON project files through `core/src/project.zig`. Existing schema-1 files must keep loading; keyframe arrays are optional on read and emitted on write after implementation.
**Testing**: Zig unit tests for edit/keyframe behavior and project persistence; core CLI smoke output; CMake/Qt build validation; manual Qt smoke for edit controls until UI automation exists.
**Target Platform**: Linux desktop.
**Project Type**: Native desktop application with a Zig static core library, C ABI header, Qt executable, and headless CLI.
**Performance Goals**: Basic timeline edits and redraws for small projects should be immediate; no operation in this mission performs media probing, decoding, thumbnailing, waveform generation, or render work.
**Constraints**: Zig core owns timeline truth. Qt calls through `core/include/pontificate_core.h`. Invalid operations return explicit statuses and must not partially mutate timeline state. Timeline zoom must survive redraw.
**Scale/Scope**: Early editor surface for small creator projects with asset-backed clips; not a production NLE timeline engine.

## Charter Check

The project charter requires Linux as the first-class target, focused review before merge, project-declared quality gates, and consistency between spec, plan, tasks, implementation, and review artifacts.

No charter exception is required. This mission stays inside the declared Zig + Qt stack and the existing validation commands.

Re-check before accept:

- `zig build test`
- `zig build run`
- `cmake -S . -B build`
- `cmake --build build`
- `git diff --check`

## Project Structure

### Documentation (this mission)

```
kitty-specs/timeline-editing-and-keyframe-engine-01KTJVYN/
├── spec.md
├── plan.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── pontificate-core-editing-c-abi.md
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
    ├── media.zig
    ├── pontificate.zig
    ├── project.zig
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

**Structure Decision**: Keep the current single native application structure. Expand `core/src/timeline.zig` for edit and keyframe domain behavior, `core/src/project.zig` for project-level orchestration and JSON compatibility, `core/src/pontificate.zig` plus `core/include/pontificate_core.h` for ABI calls, and `ui/src/main.cpp` for first-pass editing controls. Do not split the Qt shell yet; this mission can remain inside the existing file without creating a new UI architecture.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Optional keyframe data in schema-1 project files | Existing projects lack keyframe arrays but new projects need persistence. | Bumping the schema immediately would make the previous mission's files fail the backward-compatibility requirement. |
| C ABI editing functions | Qt needs to exercise real core-owned edits. | UI-only edits would violate core ownership and make save/load inconsistent. |
| Explicit edit rollback behavior | Invalid edits must not partially mutate state. | Mutating first and validating later would make failures hard to reason about across the C ABI. |

## Architecture And Data Flow

1. Qt owns presentation state only: selected asset index, selected clip index, zoom percent, and input controls.
2. The Zig core owns project state: media assets, clips, track assignment, timing, blend mode, opacity, and keyframes.
3. Qt requests edits through C ABI functions using clip indexes or clip IDs chosen by the implementation plan.
4. The project layer resolves asset/clip references and delegates timeline validation to `timeline.zig`.
5. Timeline operations validate all inputs before mutating:
   - split requires a time strictly inside the clip span
   - trim requires positive remaining duration
   - move requires non-negative timeline time and compatible target track
   - keyframe insert requires supported property, finite non-negative time, and valid value
6. Timeline summaries are generated in deterministic track/time order so Qt can redraw without owning ordering rules.
7. Save/load persists timeline edits and keyframes. Loading old schema-1 files without keyframes produces clips with empty keyframe curves and existing opacity/blend defaults.
8. Qt refreshes the timeline from core summaries after each edit and reapplies the current zoom percent.

## Data Model Decisions

### Keyframe Value Shape

Use scalar keyframe values in this mission, with `opacity` as the first supported property. Keep the public enum/property model extensible for transform, color, subtitle style, blend/grade mix, and transition parameters.

Reasoning:

- Opacity proves insert, replace, order, interpolate, persist, load, and summarize behavior.
- Scalar interpolation is enough for fades and grade mix.
- Vector/color values can be layered on later without blocking the shared curve semantics.

### Duplicate Keyframe Policy

Inserting a keyframe for the same property at the same time replaces the existing value. This keeps UI behavior natural for inspector-style editing and prevents duplicate-time ambiguity during interpolation.

### Timeline Overlap Policy

Allow same-track overlaps in the core for now unless an operation creates invalid timing or incompatible tracks. Transition and collision semantics are future work. Deterministic ordering by track/time/clip ID keeps display stable even before overlap policy matures.

### C ABI Addressing

Prefer clip indexes for first-pass Qt calls because the current UI already consumes index-based summaries. Internally, the core should preserve clip IDs and may expose ID-based functions later. Any index-based function must return `PONTIFICATE_STATUS_OUT_OF_RANGE` for stale or invalid indexes.

## C ABI Decision

Add editing functions to `core/include/pontificate_core.h` and implementations in `core/src/pontificate.zig`.

Expected shape:

```c
uint32_t pontificate_project_split_clip(PontificateProject *project, uint32_t clip_index, double split_time);
uint32_t pontificate_project_trim_clip(PontificateProject *project, uint32_t clip_index, double new_timeline_start, double new_source_in, double new_duration);
uint32_t pontificate_project_move_clip(PontificateProject *project, uint32_t clip_index, uint32_t track_index, double timeline_start);
uint32_t pontificate_project_set_clip_opacity_keyframe(PontificateProject *project, uint32_t clip_index, double clip_time, double value);
double pontificate_project_evaluate_clip_opacity(const PontificateProject *project, uint32_t clip_index, double clip_time, uint32_t *status_out);
```

The exact names may change, but the ABI must keep ownership simple and status-driven. Summary-buffer APIs can continue for display text. If detailed keyframe summaries are needed, add caller-owned buffer functions rather than returning Zig-owned memory.

## Testing Strategy

Add Zig tests for:

- split inside clip span produces two clips with correct timeline/source timing
- split at clip boundary is rejected without mutation
- trim updates timeline start, source in-point, and duration
- invalid trim rejects without mutation
- move updates time/track for compatible targets
- incompatible move rejects without mutation
- summaries sort by track, time, then clip ID
- opacity keyframes insert, replace, sort, and evaluate
- project JSON write/load preserves keyframes
- old schema-1 JSON without keyframes loads with empty/default keyframe state

Add C ABI coverage through exported functions exercised by Zig tests where practical, plus Qt build validation.

Manual Qt smoke:

1. Launch the app.
2. Import a media asset.
3. Add it to the timeline.
4. Select the clip.
5. Use split/trim/move controls.
6. Confirm the timeline redraws and zoom is preserved.

Required final commands:

```sh
zig build test
zig build run
cmake -S . -B build
cmake --build build
git diff --check
git status --short --branch
```

## Risks

- Clip indexes can become stale after split/sort. Qt should refresh selection after edits, and ABI functions must guard indexes.
- Same-track overlap behavior is intentionally permissive. Later transition/ripple missions must revisit collision rules.
- JSON compatibility can break if optional keyframe arrays are not modeled carefully.
- C ABI status mapping can hide edit-specific errors if it remains too coarse. Use existing statuses first, but keep error cases documented in tests.
- Qt timeline controls may tempt a larger interaction rewrite. Keep controls minimal and data-driven for this mission.

## Implementation Concern Map

### IC-01 - Core Timeline Edit Operations

- **Purpose**: Add split, trim, move, validation, rollback-safe mutation, and deterministic ordering to the core timeline model.
- **Relevant requirements**: FR-001, FR-002, FR-003, FR-004, FR-005, NFR-001, NFR-003, C-001
- **Affected surfaces**: `core/src/timeline.zig`, `core/src/project.zig`
- **Sequencing/depends-on**: none
- **Risks**: Split and sort behavior must not invalidate project asset references or silently reorder in surprising ways.

### IC-02 - Keyframe Domain Model

- **Purpose**: Introduce supported keyframe properties, scalar keyframe curves, insert/replace policy, interpolation, and evaluation.
- **Relevant requirements**: FR-006, FR-007, FR-008, NFR-001, C-001
- **Affected surfaces**: `core/src/timeline.zig`, `core/src/project.zig`
- **Sequencing/depends-on**: IC-01 can proceed in parallel conceptually, but persistence should land after the core model exists.
- **Risks**: Avoid overbuilding typed vector/color systems before the first scalar property is proven.

### IC-03 - Project Persistence Compatibility

- **Purpose**: Save and load edited clip placements and keyframes while preserving compatibility with prior schema-1 project files.
- **Relevant requirements**: FR-008, FR-009, SC-003, SC-004, SC-007
- **Affected surfaces**: `core/src/project.zig`, `core/src/main.zig`
- **Sequencing/depends-on**: IC-01, IC-02
- **Risks**: Optional JSON fields must use defaults cleanly; test old JSON explicitly.

### IC-04 - C ABI Editing Boundary

- **Purpose**: Expose split, trim, move, opacity keyframe insertion, and opacity evaluation through the Qt-facing boundary.
- **Relevant requirements**: FR-010, FR-012, NFR-003, C-003
- **Affected surfaces**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`
- **Sequencing/depends-on**: IC-01, IC-02, IC-03
- **Risks**: Index-based ABI calls must fail clearly when Qt selection is stale after redraw.

### IC-05 - Qt Timeline Editing Affordances

- **Purpose**: Add first-pass controls for selected-clip split/trim/move and redraw timeline from core summaries while preserving zoom.
- **Relevant requirements**: FR-011, SC-005, SC-006, NFR-004
- **Affected surfaces**: `ui/src/main.cpp`
- **Sequencing/depends-on**: IC-04
- **Risks**: Keep UI controls modest; this is not the full interaction design for drag editing.

### IC-06 - Documentation And Validation

- **Purpose**: Align public docs and mission artifacts with shipped edit/keyframe behavior and non-goals.
- **Relevant requirements**: FR-013, NFR-002, C-004, C-005, C-006, C-007, C-008
- **Affected surfaces**: `README.md`, `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, mission artifacts
- **Sequencing/depends-on**: IC-01 through IC-05
- **Risks**: Do not overclaim color, subtitles, playback, transitions, or packaging as shipped.
