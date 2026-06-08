---
work_package_id: WP02
title: Project Persistence And CLI Editing Inspection
dependencies:
- WP01
requirement_refs:
- FR-008
- FR-009
- FR-012
- NFR-001
- NFR-002
- NFR-003
- C-001
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-timeline-editing-and-keyframe-engine-01KTJVYN
base_commit: 0c4ab13b3109addb9ab0890f83cb4221822d4e22
created_at: '2026-06-08T07:06:37.310004+00:00'
subtasks:
- T008
- T009
- T010
- T011
- T012
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

# Work Package Prompt: WP02 - Project Persistence And CLI Editing Inspection

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Integrate WP01 timeline edit/keyframe behavior into the project model, JSON save/load, and headless CLI inspection path. Preserve compatibility with project files produced by the previous foundation mission.

## Context

`core/src/project.zig` owns media assets and delegates timeline behavior to `timeline.zig`. This WP should expose project-level methods for editing clips, persist keyframes, and keep old schema-1 JSON without keyframe arrays loadable. `core/src/main.zig` should offer enough smoke output or commands for developers to inspect edited timelines without launching Qt.

### Subtask T008: Add Project-Level Editing Methods

- **Purpose**: Give later ABI and CLI code one project-level surface for timeline edits.
- **Steps**:
  1. Add methods on `Project` that wrap timeline split, trim, move, set opacity keyframe, and evaluate opacity.
  2. Translate asset/clip index errors into existing project or timeline errors.
  3. Keep project assets immutable during timeline-only edits.
- **Files**: Modify `core/src/project.zig`.
- **Validation**: Add tests that create/import/add a clip, call project-level edit methods, and verify clip summaries.

### Subtask T009: Persist Edited Clip State And Keyframes

- **Purpose**: Save/load split, moved, trimmed, and keyframed timeline state.
- **Steps**:
  1. Extend serialized clip JSON to include keyframe arrays or optional keyframe data.
  2. Emit keyframe data when saving new projects.
  3. Restore keyframe data when loading.
  4. Preserve existing clip fields: ID, asset ID, track, timeline start, source in, duration, opacity, and blend mode.
- **Files**: Modify `core/src/project.zig`.
- **Validation**: Add round-trip tests for moved/trimmed clips and opacity keyframes.

### Subtask T010: Preserve Backward Compatibility

- **Purpose**: Keep previous schema-1 project JSON loadable.
- **Steps**:
  1. Make new keyframe fields optional in deserialization.
  2. Add an explicit test fixture using old JSON with no keyframe fields.
  3. Verify loaded clips retain default opacity and empty keyframe curves.
  4. Keep `schema_version` unchanged unless a strong reason emerges; document any change in tests if needed.
- **Files**: Modify `core/src/project.zig`.
- **Validation**: `zig build test` with an old-schema fixture.

### Subtask T011: Extend CLI Inspection

- **Purpose**: Let developers inspect edited timeline/keyframe state headlessly.
- **Steps**:
  1. Update `core/src/main.zig` to include edited timeline/keyframe details in existing smoke output or add small inspect behavior consistent with current CLI patterns.
  2. Avoid adding a heavyweight argument parser.
  3. Include clip count, ordered clip summaries, and opacity evaluation evidence.
- **Files**: Modify `core/src/main.zig`.
- **Validation**: `zig build run` prints stable output that reflects edit/keyframe capability.

### Subtask T012: Add Integration Tests

- **Purpose**: Prove project-level persistence and CLI assumptions.
- **Steps**:
  1. Add tests covering save/load after split, trim, move, and opacity keyframes.
  2. Verify invalid project-level edits do not mutate project state.
  3. Ensure offline/missing media behavior from the prior mission still passes.
- **Files**: Modify `core/src/project.zig`, `core/src/main.zig`.
- **Validation**: `zig build test` and `zig build run`.

## Definition of Done

- Project-level edit/keyframe methods exist and are tested.
- Project JSON persists keyframes and remains compatible with previous schema-1 files.
- CLI output provides headless evidence of timeline/keyframe behavior.
- Existing media-library and missing-media tests still pass.

## Risks

- Optional JSON fields can be easy to model incorrectly in Zig 0.16; keep tests small and explicit.
- Project-level wrappers should not duplicate validation already owned by `timeline.zig`.
- CLI output should stay stable enough for smoke validation without becoming a real command framework.

## Reviewer Guidance

Focus on JSON compatibility, project/timeline responsibility boundaries, and whether failed project-level edits leave state unchanged. Run `zig build test` and `zig build run`.

Implementation command: `spec-kitty agent action implement WP02 --agent <name>`

## Activity Log

- 2026-06-08T07:10:34Z – codex – shell_pid=2943638 – Implemented project edit wrappers, JSON media_kind/keyframe persistence, schema-1 compatibility, and CLI inspect clip opacity output; validation: zig build test, zig build run, git diff --check.
- 2026-06-08T07:11:00Z – codex – shell_pid=2943638 – Started review via action command
