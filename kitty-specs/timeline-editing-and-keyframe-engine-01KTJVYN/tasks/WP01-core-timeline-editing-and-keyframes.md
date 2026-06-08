---
work_package_id: WP01
title: Core Timeline Editing And Keyframes
dependencies: []
requirement_refs:
- FR-001
- FR-002
- FR-003
- FR-004
- FR-005
- FR-006
- FR-007
- NFR-001
- NFR-003
- C-001
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-timeline-editing-and-keyframe-engine-01KTJVYN
base_commit: 5f3e9e5709d1640777a1165fe1ec67bee8a1a5a9
created_at: '2026-06-08T06:49:12.226103+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
- T006
- T007
agent: "codex"
shell_pid: "2943638"
history: []
agent_profile: implementer-ivan
authoritative_surface: core/src/timeline.zig
execution_mode: code_change
model: ''
owned_files:
- core/src/timeline.zig
role: implementer
tags: []
---

# Work Package Prompt: WP01 - Core Timeline Editing And Keyframes

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Implement deterministic core timeline edit operations and the first reusable keyframe model in `core/src/timeline.zig`. This WP must keep all validation and mutation semantics in the Zig core and prove them with unit tests.

## Context

The previous mission created asset-backed clips with timeline start, source in, duration, opacity, and blend mode. This mission needs split, trim, move, sorted summaries, and opacity keyframes without adding playback, decoding, export, or UI interaction complexity. Later WPs depend on these APIs for project persistence, the C ABI, and Qt controls.

### Subtask T001: Define Edit And Keyframe Types

- **Purpose**: Add the domain types needed for edit operations and scalar keyframes.
- **Steps**:
  1. In `core/src/timeline.zig`, add public edit placement/trim structs or function parameters that express split, trim, and move intent.
  2. Add a `KeyframeProperty` enum with at least `opacity`.
  3. Add scalar keyframe structs with `time`, `value`, and interpolation mode.
  4. Store opacity keyframes on `TimelineClip` while preserving existing `opacity` default behavior.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: `zig build test` should still pass existing tests before behavior is added.

### Subtask T002: Implement Split Operation

- **Purpose**: Split a clip at a time strictly inside its timeline span.
- **Steps**:
  1. Add a `splitClip` operation that accepts a clip index or ID and a timeline time.
  2. Reject split times at the clip start, at the clip end, outside the span, negative, NaN, or infinite.
  3. Preserve the original clip as the left segment and create a new clip as the right segment.
  4. Set the right segment's timeline start, source in, duration, asset ID, track, blend mode, opacity, and relevant keyframe data deterministically.
  5. Advance `next_clip_id` only after validation succeeds.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: Add tests for a 5s clip split at 2s producing 2s and 3s segments with source in-points 0s and 2s.

### Subtask T003: Implement Trim Operation

- **Purpose**: Update clip timeline start, source in-point, and duration without creating invalid spans.
- **Steps**:
  1. Add a trim operation that updates a clip after validating all new values.
  2. Reject negative timeline start, negative source in, zero/negative duration, NaN, or infinite values.
  3. Ensure failed trims leave the original clip unchanged.
  4. Keep keyframes clip-local; do not rewrite keyframe times unless the implementation explicitly documents a safe policy.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: Add tests for valid trims and failed trims with state comparison before/after failure.

### Subtask T004: Implement Move And Track Compatibility

- **Purpose**: Move clips along the timeline and between compatible tracks.
- **Steps**:
  1. Add a move operation accepting target track index or track ID and target timeline start.
  2. Reuse or add a compatibility helper mapping media kind to compatible track kind.
  3. Reject incompatible track targets and negative/invalid times.
  4. Allow same-track overlaps for now, per plan, but keep ordering deterministic.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: Add tests for valid same-track moves, valid compatible track moves where applicable, and invalid incompatible moves.

### Subtask T005: Implement Deterministic Summary Ordering

- **Purpose**: Let consumers redraw from track/time/clip-ID order instead of append order.
- **Steps**:
  1. Add helper behavior for sorting or selecting summary order by track index, timeline start, then clip ID.
  2. Preserve stable clip IDs and asset references.
  3. Decide whether the underlying `clips` array is kept sorted after each mutation or summaries are sorted when requested; document the choice in tests.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: Add tests with clips inserted/moved out of order and verify summary order.

### Subtask T006: Implement Opacity Keyframe Insert And Evaluation

- **Purpose**: Prove the reusable keyframe engine with one scalar property.
- **Steps**:
  1. Add an insert/set function for opacity keyframes.
  2. Use replace-on-same-time semantics.
  3. Keep keyframes sorted by time.
  4. Evaluate before first keyframe, between keyframes, and after last keyframe.
  5. Use linear interpolation for the first implementation.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: Add tests for insert, replace, ordering, and interpolation at 0.5s between 0.0 and 1.0.

### Subtask T007: Add Failure-Atomic Tests

- **Purpose**: Make invalid edit behavior reviewable.
- **Steps**:
  1. Add tests that snapshot relevant clip state before invalid split, trim, move, and keyframe calls.
  2. Verify counts, IDs, timing, and keyframe arrays are unchanged after each failure.
  3. Keep test helpers local to `timeline.zig` unless reused by later WPs.
- **Files**: Modify `core/src/timeline.zig`.
- **Validation**: `zig build test`.

## Definition of Done

- `core/src/timeline.zig` exposes core edit/keyframe APIs usable by project integration.
- Split, trim, move, ordering, keyframe insert/replace, and evaluation are covered by tests.
- Invalid operations return explicit errors and do not partially mutate state.
- No media playback, decoding, render, thumbnail, or proxy behavior is added.

## Risks

- Clip indexes can become stale after sort or split; keep return values and tests clear.
- Keyframe copying during split can get complicated; implement the smallest documented behavior that preserves opacity evaluation predictably.
- Same-track overlap is intentionally permissive for now; do not add hidden collision policy.

## Reviewer Guidance

Review validation-before-mutation, split source timing, keyframe replacement semantics, and whether summary ordering is deterministic. Run `zig build test`.

Implementation command: `spec-kitty agent action implement WP01 --agent <name>`

## Activity Log

- 2026-06-08T06:57:50Z – codex – shell_pid=2943638 – Implemented core timeline edit operations and opacity keyframes; validation: zig build test, zig build run, git diff --check.
- 2026-06-08T06:58:47Z – codex – shell_pid=2943638 – Started review via action command
