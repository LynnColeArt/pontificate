---
work_package_id: WP05
title: Documentation Contracts And Validation Notes
dependencies:
- WP04
requirement_refs:
- FR-013
- NFR-002
- NFR-005
- C-004
- C-005
- C-006
- C-007
- C-008
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T021
- T022
- T023
- T024
agent: codex
history: []
agent_profile: curator-carla
authoritative_surface: docs/
execution_mode: planning_artifact
model: ''
owned_files:
- README.md
- docs/**
role: curator
tags: []
---

# Work Package Prompt: WP05 - Documentation Contracts And Validation Notes

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `curator-carla`
- **Role**: `curator`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Update public docs so the shipped timeline/keyframe behavior is clear without overclaiming future playback, transition, subtitle, color, or packaging capabilities.

## Context

This mission creates the shared keyframe/editing spine for future features. Mission-local data model, contract, and quickstart planning artifacts already exist under `kitty-specs/`; implementation WPs must not claim `kitty-specs/` paths as owned files. This WP runs after implementation so public docs can match shipped behavior.

### Subtask T021: Verify Data Model Alignment

- **Purpose**: Ensure public docs use the same terminology as the mission data model.
- **Steps**:
  1. Read `kitty-specs/timeline-editing-and-keyframe-engine-01KTJVYN/data-model.md`.
  2. Use the same entity names when updating `README.md` and `docs/**`.
  3. Note scalar opacity as the first supported keyframe property.
- **Files**: Modify `README.md`, `docs/**`.
- **Validation**: Public docs match the mission data model.

### Subtask T022: Verify C ABI Contract Alignment

- **Purpose**: Ensure public docs agree with the mission C ABI contract and header.
- **Steps**:
  1. Read `kitty-specs/timeline-editing-and-keyframe-engine-01KTJVYN/contracts/pontificate-core-editing-c-abi.md`.
  2. Compare function names with `core/include/pontificate_core.h`.
  3. Mention the C ABI boundary in public architecture docs without duplicating all contract detail.
- **Files**: Modify `README.md`, `docs/**`.
- **Validation**: Public docs and header do not contradict the mission contract.

### Subtask T023: Update Public Docs

- **Purpose**: Keep README and architecture/features docs honest and useful.
- **Steps**:
  1. Update `README.md` for current timeline editing/keyframe capability and validation commands.
  2. Update `docs/FEATURES.md` to separate shipped edit/keyframe foundation from roadmap features.
  3. Update `docs/ARCHITECTURE.md` to explain core-owned timeline operations and Qt presentation ownership.
  4. Avoid claiming playback, render/export, full transition authoring, color room, subtitles/Whisper, or packaging as done.
- **Files**: Modify `README.md`, `docs/FEATURES.md`, `docs/ARCHITECTURE.md`.
- **Validation**: Docs match implementation and spec non-goals.

### Subtask T024: Update Validation Notes

- **Purpose**: Give reviewers a repeatable smoke path.
- **Steps**:
  1. Read `kitty-specs/timeline-editing-and-keyframe-engine-01KTJVYN/quickstart.md`.
  2. Ensure `README.md` or docs list current validation commands: `zig build test`, `zig build run`, `cmake -S . -B build`, `cmake --build build`, and `git diff --check`.
  3. Include or reference a manual Qt smoke path for import, add to timeline, zoom, split/trim/move, and opacity keyframe.
  4. Mention that media files are reference-based and no playback engine exists yet.
- **Files**: Modify `README.md`, `docs/**`.
- **Validation**: Commands are current and manual steps are realistic.

## Definition of Done

- Public docs align with the mission data model, C ABI contract, and quickstart artifacts.
- README and docs reflect shipped behavior and non-goals.
- Validation commands are documented and pass at mission close.
- No generated local agent payloads or temporary worktrees are published.

## Risks

- Documentation can accidentally imply future color/subtitle/playback features are shipped. Keep language precise.
- Contract notes can drift from the header if implementation changes late; verify after code WPs.
- Quickstart should not depend on media decoding or a particular external sample file.

## Reviewer Guidance

Review for truthfulness, exact ABI names, and clear non-goals. Run the documented commands and compare docs against implemented behavior.

Implementation command: `spec-kitty agent action implement WP05 --agent <name>`
