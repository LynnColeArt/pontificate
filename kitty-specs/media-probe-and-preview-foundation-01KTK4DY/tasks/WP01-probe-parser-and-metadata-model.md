---
work_package_id: WP01
title: Probe Parser And Metadata Model
dependencies: []
requirement_refs:
- FR-001
- FR-002
- FR-003
- NFR-001
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
- T001
- T002
- T003
- T004
- T005
- T006
agent: "codex"
history: []
agent_profile: implementer-ivan
authoritative_surface: core/src/probe.zig
execution_mode: code_change
model: ''
owned_files:
- core/src/probe.zig
- core/src/media.zig
- build.zig
role: implementer
tags: []
---

# Work Package Prompt: WP01 - Probe Parser And Metadata Model

## Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

## Objective

Implement the core probe data model and deterministic `ffprobe` JSON parser. This WP must not require real media files or installed FFmpeg tools to pass tests.

## Context

Pontificate currently classifies media by extension and stores optional duration/dimensions manually. The next layer needs a typed metadata model with explicit probe statuses so later project, ABI, and Qt work can depend on stable behavior.

### Subtask T001: Add Probe Metadata Types

- Add a `ProbeStatus` enum with unprobed, available, tool-unavailable, failed, malformed, and unsupported states.
- Add metadata fields for duration, dimensions, frame rate, stream flags, and optional codec/container labels.
- Keep media availability separate from probe status.

### Subtask T002: Add Parser Boundary

- Create `core/src/probe.zig`.
- Define result structs and parser entry points for `ffprobe` JSON.
- Keep process execution out of this first parser boundary unless a tiny helper is needed for type shaping.

### Subtask T003: Parse Successful Fixtures

- Add fixture strings for video with audio, audio-only, and missing-field cases.
- Parse duration, dimensions, frame rate, stream flags, and labels where present.
- Treat unknown or `N/A` values as absent.

### Subtask T004: Map Failure Outcomes

- Map malformed JSON to malformed status.
- Represent unsupported media kinds explicitly.
- Reserve tool-unavailable and failed statuses for the later process adapter.

### Subtask T005: Add Tests

- Cover success, missing fields, audio-only no-dimensions behavior, malformed output, and unsupported kinds.
- Ensure existing media classification tests still pass.

### Subtask T006: Wire Test Coverage

- Ensure the new module is imported by the core package or otherwise included by `zig build test`.
- Do not add external dependencies.

## Definition of Done

- Probe metadata types exist and are reusable by `media.zig` and `project.zig`.
- Parser tests are deterministic and do not need FFmpeg installed.
- Audio-only assets do not invent video dimensions.
- Unknown values remain unknown.

## Reviewer Guidance

Review the parser for overfitting, status clarity, and safe handling of `N/A` or missing values. Run `zig build test`.
