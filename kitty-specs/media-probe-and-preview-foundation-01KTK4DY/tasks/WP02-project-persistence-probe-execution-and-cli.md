---
work_package_id: WP02
title: Project Persistence Probe Execution And CLI
dependencies:
- WP01
requirement_refs:
- FR-001
- FR-002
- FR-003
- FR-004
- FR-005
- FR-007
- FR-012
- SC-002
- SC-003
- SC-005
- SC-009
- NFR-001
- NFR-002
- NFR-003
- NFR-004
- C-001
- C-002
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission live on kitty/mission-media-probe-and-preview-foundation-01KTK4DY. Implementation lanes may branch from dependency-specific bases, but completed changes must merge back into main unless the human redirects the landing branch.
base_branch: kitty/mission-media-probe-and-preview-foundation-01KTK4DY
base_commit: aaf1addbdb767cef83cf2a70d5a4c7b78add5194
created_at: '2026-06-08T08:21:08+00:00'
subtasks:
- T007
- T008
- T009
- T010
- T011
- T012
agent: "codex"
history: []
agent_profile: implementer-ivan
authoritative_surface: core/src/project.zig
execution_mode: code_change
model: ''
owned_files:
- core/src/project.zig
- core/src/main.zig
- core/src/media.zig
role: implementer
tags: []
---

# Work Package Prompt: WP02 - Project Persistence Probe Execution And CLI

## Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

## Objective

Persist probe metadata on assets, add explicit project-level probe execution, expose probe information through CLI inspection, and use known source duration when creating new timeline clips.

## Context

WP01 supplies parser and metadata types. This WP connects them to project state while keeping import cheap, old schema-1 files loadable, and missing tools non-fatal.

### Subtask T007: Persist Probe Metadata

- Extend project JSON write/load for probe status and metadata.
- Keep optional fields backward compatible with prior schema-1 project files.

### Subtask T008: Load Old Files With Defaults

- Add tests using old asset JSON without probe fields.
- Default those assets to unprobed metadata.

### Subtask T009: Add Probe Execution

- Add an explicit project operation to probe an asset by index.
- Invoke `ffprobe` with argv arguments, never shell interpolation.
- Map missing tool, nonzero exit, malformed output, and unsupported kind to explicit probe statuses.

### Subtask T010: Preserve Metadata Across Offline Revalidation

- Loading a project may mark `MediaStatus` as missing, but it must not discard persisted metadata.

### Subtask T011: Use Known Duration For New Clips

- When adding video/audio assets to the timeline, use known positive probed duration.
- Keep still image and unprobed fallback behavior unchanged.
- Do not rewrite existing clips when an asset is later probed.

### Subtask T012: Extend CLI Output

- Update `inspect` output or add a dedicated probe inspection command.
- Include probe status and known metadata in headless output.

## Definition of Done

- Project JSON round trip preserves probe metadata.
- Old schema-1 project JSON still loads.
- Missing `ffprobe` does not crash import, load, save, or CLI inspection.
- `zig build test` and `zig build run` pass.

## Reviewer Guidance

Review process invocation safety, JSON compatibility, and the distinction between media availability and probe status. Run `zig build test` and a CLI smoke command.
