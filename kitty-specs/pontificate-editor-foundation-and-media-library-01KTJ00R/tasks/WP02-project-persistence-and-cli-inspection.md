---
work_package_id: WP02
title: Project Persistence And CLI Inspection
dependencies:
- WP01
requirement_refs:
- FR-001
- FR-003
- FR-004
- FR-005
- FR-009
- NFR-001
- NFR-004
- NFR-005
- C-001
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-pontificate-editor-foundation-and-media-library-01KTJ00R
base_commit: 8e44085a7dcbe7a78132fd4b72364170685571bb
created_at: '2026-06-08T04:36:19.669555+00:00'
subtasks:
- T006
- T007
- T008
- T009
- T010
- T011
agent: "codex"
shell_pid: "2943638"
history: []
agent_profile: implementer-ivan
authoritative_surface: core/src/
execution_mode: code_change
model: ''
owned_files:
- core/src/project.zig
- core/src/main.zig
role: implementer
tags: []
---

# WP02: Project Persistence And CLI Inspection

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement the core project document model, media-library import behavior, JSON save/load, missing-media revalidation, and a headless CLI inspection path. This package depends on WP01's media types and should remain independent from Qt and C ABI concerns.

## Context

The mission chooses JSON schema version `1` and reference-based media paths. The project owns imported assets and timeline state, but timeline clip behavior itself is WP03. This package should make persistence real enough that later UI work can trust the core.

Implementation command: `spec-kitty agent action implement WP02 --agent <name>`

### Subtask T006: Create Project Document Types

**Purpose**: Establish a project root that owns media-library state.

**Steps**:
1. Create `core/src/project.zig`.
2. Import WP01's `media.zig` module with a relative import.
3. Define a `Project` type with schema version, project ID, media assets collection, and placeholders for tracks/clips that WP03 can integrate later.
4. Provide initialization and deinitialization APIs with explicit allocator ownership.
5. Keep the initial project valid when empty.

**Files**: `core/src/project.zig`.

**Validation**: Add tests for empty project initialization and cleanup.

### Subtask T007: Implement Import And Duplicate Handling

**Purpose**: Make project-level media import satisfy FR-001, FR-003, and FR-004.

**Steps**:
1. Add a project import function that accepts a selected source path.
2. Use WP01 classification and duplicate-key helpers.
3. Check filesystem existence enough to mark available vs missing; avoid opening or decoding the media.
4. Reject or mark unsupported unknown extensions with an explicit result, as long as behavior is deterministic and visible to callers.
5. Ensure importing the same normalized path twice does not create duplicate assets.
6. Preserve missing/offline asset records when policy chooses offline import.

**Files**: `core/src/project.zig`.

**Validation**: Tests should cover single import, multi-import loop behavior, duplicate path, missing file, unknown extension, and paths with spaces.

### Subtask T008: Serialize Project JSON Schema V1

**Purpose**: Save library state across sessions.

**Steps**:
1. Implement save-to-file or save-to-writer behavior using Zig standard-library JSON APIs.
2. Emit `schema_version: 1`, a project ID, assets, and empty/default timeline containers.
3. Persist asset IDs, display names, source paths, media kinds, and availability statuses.
4. Keep optional fields explicit or consistently omitted; avoid a sprawling schema.
5. Return explicit errors for write failures.

**Files**: `core/src/project.zig`.

**Validation**: Round-trip test should verify 100% preservation of imported asset fields required by SC-002.

### Subtask T009: Load Project JSON And Revalidate Missing Media

**Purpose**: Restore saved libraries while preserving offline/missing assets.

**Steps**:
1. Implement load-from-file or load-from-reader behavior.
2. Validate `schema_version` and produce a clear error for unsupported schemas.
3. Reconstruct stable asset IDs and source paths.
4. Re-check source path availability on load and mark missing files offline instead of dropping the asset.
5. Return clear parsing errors for malformed JSON.

**Files**: `core/src/project.zig`.

**Validation**: Tests should cover valid round trip, missing source file on load, unsupported schema, and malformed JSON.

### Subtask T010: Add CLI Project Inspection

**Purpose**: Provide a developer-visible validation path that does not depend on Qt.

**Steps**:
1. Update `core/src/main.zig` to accept a small command shape such as default summary, import-and-save smoke, or summarize project file.
2. Keep existing demo output useful until the full project path exists.
3. Add a CLI mode that loads a project file and prints asset count, clip count placeholder, and a compact per-asset summary.
4. Make errors clear on stdout/stderr and return nonzero on load failure.
5. Keep the CLI independent of Qt and C ABI.

**Files**: `core/src/main.zig`.

**Validation**: `zig build run` should still work, and a project summary command should be manually runnable after WP04 wires the module into the build.

### Subtask T011: Add Project Tests

**Purpose**: Lock down persistence behavior before the UI consumes it.

**Steps**:
1. Add tests in `project.zig` for import, duplicate handling, missing/offline state, and save/load.
2. Use temporary directories/files from Zig test helpers where possible.
3. Ensure tests do not depend on external media decoders.
4. Keep failure messages clear enough to diagnose schema regressions.

**Files**: `core/src/project.zig`.

**Validation**: Run `zig test core/src/project.zig` while developing and `zig build test` after WP04 integration.

## Definition of Done

- Project state initializes empty and owns media-library assets.
- Project import uses WP01 media semantics and handles duplicates deterministically.
- JSON save/load preserves required asset fields.
- Loading projects with missing source files preserves offline records.
- CLI project inspection exists and fails clearly on invalid files.
- Tests cover import, duplicate, missing, save/load, and path-with-spaces behavior.

## Risks

- Zig JSON APIs may be fussy in 0.16. Keep schema small and tests direct.
- Avoid building a migration framework. Schema version validation is enough for v1.
- Do not let CLI formatting become the C ABI contract; WP04 owns the Qt-facing boundary.

## Reviewer Guidance

Check allocator ownership, JSON stability, and clear failure states. Confirm this WP does not introduce playback, FFmpeg/GStreamer, thumbnails, or Qt state ownership.

## Activity Log

- 2026-06-08T04:43:34Z – codex – shell_pid=2943638 – Started review via action command
