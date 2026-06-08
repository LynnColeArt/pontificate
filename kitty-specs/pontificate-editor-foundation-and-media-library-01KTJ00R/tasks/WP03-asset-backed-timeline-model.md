---
work_package_id: WP03
title: Asset Backed Timeline Model
dependencies:
- WP01
- WP02
requirement_refs:
- FR-001
- FR-007
- FR-008
- NFR-001
- C-001
- C-004
- C-005
- C-006
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-pontificate-editor-foundation-and-media-library-01KTJ00R
base_commit: 4e817ce35ade8bec3e08d08917bf2644c142374e
created_at: '2026-06-08T04:45:23.439067+00:00'
subtasks:
- T012
- T013
- T014
- T015
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

# WP03: Asset Backed Timeline Model

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Create the initial timeline model that can reference imported media assets. This package owns track and clip data structures plus asset-backed clip creation, but it should not implement trim, ripple, playback, waveforms, subtitles, or color darkroom behavior.

## Context

The Qt timeline already has zoom and hardcoded clips. This package gives the core a data model for those clips so WP04 can expose summaries and WP05 can render them. Timeline zoom remains a UI transform; the core should not know about pixels or viewport scale.

Implementation command: `spec-kitty agent action implement WP03 --agent <name>`

### Subtask T012: Define Track And Clip Types

**Purpose**: Give Pontificate timeline state a core-owned representation.

**Steps**:
1. Create `core/src/timeline.zig`.
2. Define `TrackKind` compatible with current editor concepts: video, audio, subtitle, and adjustment.
3. Define `TimelineTrack` with stable ID or index, display name, and track kind.
4. Define `TimelineClip` with stable clip ID, referenced media asset ID, track ID/index, timeline start, source in, duration, opacity placeholder, and blend mode placeholder.
5. Keep keyframe/blend placeholders compatible with existing scaffold concepts without building the full keyframing system here.

**Files**: `core/src/timeline.zig`.

**Validation**: `zig test core/src/timeline.zig` should compile type tests locally.

### Subtask T013: Provide Default Timeline Structure

**Purpose**: Keep empty-project launch useful and prepare for data-driven rendering.

**Steps**:
1. Provide default tracks matching the current UI shape: V1, A1, Titles, and Grade.
2. Ensure default track creation does not depend on imported media.
3. Expose a helper that returns a valid empty timeline state.
4. Keep starter/demo clips separate from real project clips so WP05 can stop relying on hardcoded UI literals for normal display.

**Files**: `core/src/timeline.zig`.

**Validation**: Test that the default timeline has the expected track count and zero real clips.

### Subtask T014: Add Asset-To-Timeline Clip Creation

**Purpose**: Satisfy FR-007 by creating a clip that references an imported asset.

**Steps**:
1. Define an API that creates a clip from a media asset ID plus kind/status information supplied by project code.
2. Select a sensible default track based on media kind: video to V1, audio to A1, subtitle to Titles, unknown/image to V1 or a documented fallback.
3. Use a simple default duration when no media duration exists; do not probe files.
4. Reject or clearly fail when the referenced asset is unsupported or missing if that policy is chosen by project code.
5. Return enough information for project and C ABI layers to summarize clip labels later.

**Files**: `core/src/timeline.zig`.

**Validation**: Tests should cover creating a clip from video and audio assets, unsupported fallback behavior, and stable asset references.

### Subtask T015: Add Timeline Summary Tests

**Purpose**: Make data-driven rendering verifiable without Qt.

**Steps**:
1. Add helper functions that produce compact clip summary fields or structs for UI-facing layers.
2. Confirm labels are derived from asset/project state supplied by callers, not hardcoded global strings.
3. Verify clip count and ordering are stable.
4. Confirm timeline logic has no pixel zoom dependency.

**Files**: `core/src/timeline.zig`.

**Validation**: Run `zig test core/src/timeline.zig`, then rely on WP04 to include it in `zig build test`.

## Definition of Done

- `timeline.zig` defines default tracks and asset-backed clips.
- Clip creation stores a media asset reference and sensible timeline defaults.
- Timeline helpers support UI summaries without hardcoded demo literals.
- Tests prove clip creation and ordering.
- No trim, ripple, playback, waveform, darkroom, or subtitle-generation behavior is added.

## Risks

- It is tempting to rebuild a full NLE timeline. Keep this to the model bridge needed by the mission.
- Image duration and unsupported assets need documented fallback behavior.
- Do not move Qt zoom behavior into Zig; zoom remains presentation state.

## Reviewer Guidance

Review for small deterministic model code, clean separation from media/project ownership, and no accidental expansion into editing tools outside this mission.

## Activity Log

- 2026-06-08T04:52:09Z – codex – shell_pid=2943638 – Started review via action command
