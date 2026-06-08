---
work_package_id: WP03
title: C ABI Editing Boundary
dependencies:
- WP02
requirement_refs:
- FR-010
- FR-012
- NFR-003
- C-003
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-timeline-editing-and-keyframe-engine-01KTJVYN
base_commit: 5239813cedaa1d46f5d1b198d6a0506c12b05d89
created_at: '2026-06-08T07:12:54.791923+00:00'
subtasks:
- T013
- T014
- T015
- T016
agent: "codex"
shell_pid: "2943638"
history: []
agent_profile: implementer-ivan
authoritative_surface: core/
execution_mode: code_change
model: ''
owned_files:
- core/include/pontificate_core.h
- core/src/pontificate.zig
role: implementer
tags: []
---

# Work Package Prompt: WP03 - C ABI Editing Boundary

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Expose timeline editing and opacity keyframe behavior through the Qt-facing C ABI without leaking Zig internals or unsafe memory ownership.

## Context

Qt currently talks to the core through `core/include/pontificate_core.h` and `core/src/pontificate.zig`. The ABI uses opaque project handles, status codes, and caller-owned summary buffers. This WP extends that pattern for split, trim, move, keyframe set, and opacity evaluation.

### Subtask T013: Add C Header Declarations

- **Purpose**: Define the public editing ABI for Qt and future tests.
- **Steps**:
  1. Add declarations for split, trim, move, set opacity keyframe, and evaluate opacity.
  2. Use existing status-code style for failures.
  3. Keep ownership simple: no returned Zig-owned strings or allocations.
  4. Document whether edit functions address clips by index.
- **Files**: Modify `core/include/pontificate_core.h`.
- **Validation**: CMake must still compile the Qt shell after implementation.

### Subtask T014: Implement ABI Wrappers

- **Purpose**: Route C calls to project-level methods from WP02.
- **Steps**:
  1. Implement exported functions in `core/src/pontificate.zig`.
  2. Validate null project handles and invalid status-out pointers where applicable.
  3. Map timeline/project errors to existing ABI status codes.
  4. Ensure evaluation returns a deterministic fallback value when status reports failure.
- **Files**: Modify `core/src/pontificate.zig`.
- **Validation**: Add or update Zig tests for ABI-visible behavior where practical.

### Subtask T015: Extend Clip Summaries If Needed

- **Purpose**: Give Qt enough data to redraw and report keyframe/edit state.
- **Steps**:
  1. Review existing `pontificate_project_clip_summary`.
  2. Add keyframe count or evaluated opacity fields only if Qt needs them for this mission.
  3. Preserve existing summary format enough that current parsing does not break.
- **Files**: Modify `core/src/pontificate.zig`, `core/include/pontificate_core.h` if a new summary function is needed.
- **Validation**: Existing Qt summary parsing still works; `zig build test` passes.

### Subtask T016: Add ABI Failure Tests

- **Purpose**: Prove invalid ABI calls are explicit and non-crashing.
- **Steps**:
  1. Cover null handle behavior for edit functions.
  2. Cover stale/out-of-range clip index behavior.
  3. Cover invalid time/track/keyframe values.
  4. Verify successful calls mutate project state as expected.
- **Files**: Modify `core/src/pontificate.zig`.
- **Validation**: `zig build test`.

## Definition of Done

- Header and Zig exports expose split, trim, move, opacity keyframe set, and opacity evaluation.
- ABI functions return explicit status codes and do not expose unsafe memory ownership.
- Qt can compile against the new header.
- ABI failure paths are tested.

## Risks

- Mapping too many errors to `io_error` or `invalid` can hide useful failure modes; prefer existing specific codes where possible.
- Index-based APIs require Qt to refresh selection after split/sort.
- Summary text should remain display-oriented, not become a fragile parser contract.

## Reviewer Guidance

Review status mapping, null-handle behavior, caller-owned memory patterns, and compatibility with existing Qt C++ calls. Run `zig build test` and `cmake --build build`.

Implementation command: `spec-kitty agent action implement WP03 --agent <name>`

## Activity Log

- 2026-06-08T07:15:40Z – codex – shell_pid=2943638 – Implemented C ABI split, trim, move, opacity keyframe set, and opacity evaluation functions with explicit status mapping; validation: zig build test, zig build run, cmake -S . -B build, cmake --build build, git diff --check.
- 2026-06-08T07:16:07Z – codex – shell_pid=2943638 – Started review via action command
