---
work_package_id: WP04
title: C ABI Project Boundary
dependencies:
- WP01
- WP02
- WP03
requirement_refs:
- FR-002
- FR-006
- FR-007
- FR-008
- FR-010
- NFR-002
- NFR-003
- NFR-004
- C-001
- C-002
- C-003
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T016
- T017
- T018
- T019
- T020
- T021
agent: codex
history: []
agent_profile: implementer-ivan
authoritative_surface: core/
execution_mode: code_change
model: ''
owned_files:
- core/include/pontificate_core.h
- core/src/pontificate.zig
- build.zig
- CMakeLists.txt
role: implementer
tags: []
---

# WP04: C ABI Project Boundary

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Expose the project/media/timeline core through an explicit C ABI that Qt can call safely. This package owns the public header, Zig facade exports, and build metadata required for the new core modules.

## Context

The plan chooses an opaque project handle and caller-provided summary buffers. Do not return Zig-owned strings to Qt without a matching lifetime story. The C ABI should be good enough for WP05 to import media, refresh library rows, add clips, refresh timeline rows, and save/load project files.

Implementation command: `spec-kitty agent action implement WP04 --agent <name>`

### Subtask T016: Wire New Core Modules Into The Build

**Purpose**: Make WP01-WP03 modules part of normal core validation.

**Steps**:
1. Update `core/src/pontificate.zig` to import and re-export the needed media, project, and timeline module APIs.
2. Preserve existing version, keyframe, subtitle, and starter-summary exports unless superseded safely.
3. Update `CMakeLists.txt` dependencies so changes to new Zig files rebuild the static library.
4. Update `build.zig` only if needed to make module imports/tests work.

**Files**: `core/src/pontificate.zig`, `build.zig`, `CMakeLists.txt`.

**Validation**: Run `zig build test` after wiring.

### Subtask T017: Define Opaque Project Handle API

**Purpose**: Keep Qt from depending on Zig internals.

**Steps**:
1. Update `core/include/pontificate_core.h` with an opaque `PontificateProject` declaration.
2. Add create/destroy functions with clear null behavior.
3. Add load/save functions that accept filesystem paths.
4. Use fixed-width return codes or counts so C++ callers can interpret success/failure predictably.
5. Document buffer ownership and return semantics in comments near declarations.

**Files**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`.

**Validation**: Header should compile as C and be includable from C++17.

### Subtask T018: Export Media Library Functions

**Purpose**: Give Qt enough API surface for import and library rendering.

**Steps**:
1. Add `pontificate_project_import_path` or equivalent.
2. Add asset count and asset summary functions.
3. Use caller-provided `char *buffer` plus `buffer_len` for summary text.
4. Ensure duplicate imports return deterministic duplicate/status codes.
5. Ensure missing/unsupported imports return explicit status codes or summaries.
6. Handle null project/path/buffer arguments defensively.

**Files**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`.

**Validation**: Add Zig tests or export-level smoke checks where practical; Qt build in WP05 will exercise the header.

### Subtask T019: Export Timeline Functions

**Purpose**: Support asset-backed timeline rendering through the same boundary.

**Steps**:
1. Add an asset-to-timeline function that takes a project handle and asset index or ID.
2. Add clip count and clip summary functions.
3. Keep summaries compact and stable, for example delimited fields or readable labels. If delimited, document the delimiter and escaping limits.
4. Preserve timeline zoom as UI state; C ABI only exposes timeline model summaries.

**Files**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`.

**Validation**: Exercise add-clip and clip-summary behavior from Zig tests or CLI smoke if easy.

### Subtask T020: Preserve Legacy Scaffold Exports

**Purpose**: Avoid breaking the current app while new calls land.

**Steps**:
1. Keep `pontificate_version` and keyframe interpolation export behavior.
2. Keep default summary/count functions if the UI or CLI still uses them during transition.
3. Remove hardcoded demo dependence only when WP05 has replacement UI data flow.
4. Make any deprecated helper clearly non-authoritative for real project state.

**Files**: `core/src/pontificate.zig`, `core/include/pontificate_core.h`.

**Validation**: Existing keyframe tests should continue to pass.

### Subtask T021: Validate Core And Qt Build Boundary

**Purpose**: Prove the ABI remains usable by the shell.

**Steps**:
1. Run `zig build test`.
2. Run `zig build run`.
3. Run `cmake -S . -B build`.
4. Run `cmake --build build`.
5. Fix build dependency issues only inside this WP's owned files.

**Files**: `build.zig`, `CMakeLists.txt`, `core/include/pontificate_core.h`, `core/src/pontificate.zig`.

**Validation**: All four validation commands pass or a blocker is documented with exact error text.

## Definition of Done

- Public C header declares an opaque project handle and media/timeline functions.
- Zig exports implement create/destroy, import, asset count/summary, add-to-timeline, clip count/summary, save, and load.
- Summary buffers avoid unsafe cross-language allocation ownership.
- Build metadata tracks new Zig source files.
- Existing keyframe/version scaffold behavior is preserved unless intentionally replaced.
- `zig build test`, `zig build run`, CMake configure, and CMake build pass after this WP.

## Risks

- Returning pointers to Zig-managed memory would create lifetime bugs. Use caller buffers or explicit ownership only.
- CMake dependency lists can miss new Zig files and produce stale builds.
- Broad facade rewrites could disturb the working scaffold; keep changes direct.

## Reviewer Guidance

Review ABI naming, null handling, buffer semantics, and build dependency correctness. Confirm Qt still links through `pontificate_core.h` and does not learn Zig internals.
