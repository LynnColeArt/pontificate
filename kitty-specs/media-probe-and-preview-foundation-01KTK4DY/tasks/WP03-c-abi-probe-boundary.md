---
work_package_id: WP03
title: C ABI Probe Boundary
dependencies:
- WP02
requirement_refs:
- FR-006
- SC-004
- NFR-002
- C-004
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission live on kitty/mission-media-probe-and-preview-foundation-01KTK4DY. Implementation lanes may branch from dependency-specific bases, but completed changes must merge back into main unless the human redirects the landing branch.
base_branch: kitty/mission-media-probe-and-preview-foundation-01KTK4DY
base_commit: aaf1addbdb767cef83cf2a70d5a4c7b78add5194
created_at: '2026-06-08T08:21:08+00:00'
subtasks:
- T013
- T014
- T015
- T016
agent: "codex"
history: []
agent_profile: implementer-ivan
authoritative_surface: core/include/pontificate_core.h
execution_mode: code_change
model: ''
owned_files:
- core/include/pontificate_core.h
- core/src/pontificate.zig
role: implementer
tags: []
---

# Work Package Prompt: WP03 - C ABI Probe Boundary

## Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

## Objective

Expose project-owned probe metadata and explicit probe execution through the existing C ABI without returning Zig-owned allocations.

## Context

The Qt shell consumes opaque project handles and caller-owned summary buffers. This WP extends that boundary for probe metadata after WP02 has implemented project behavior.

### Subtask T013: Add Header Declarations

- Add `pontificate_project_probe_asset`.
- Add `pontificate_project_asset_probe_summary`.
- Document caller-owned buffer behavior and display-oriented summary text.

### Subtask T014: Implement Status Mapping

- Map null arguments, out-of-range indexes, unsupported assets, process failures, and success to existing ABI status codes.
- Keep detailed probe state in project summaries.

### Subtask T015: Implement Probe Summary Buffer

- Format known metadata into pipe-delimited key/value text.
- Return buffer-too-small without partial writes.
- Include explicit unknown/unavailable state for unprobed assets.

### Subtask T016: Add ABI Tests

- Exercise success/unknown summaries where practical.
- Cover too-small buffer behavior.
- Ensure ABI functions never expose Zig-owned memory.

## Definition of Done

- Qt can request probe status and metadata through the C ABI.
- Existing ABI calls remain source-compatible.
- `zig build test` passes.

## Reviewer Guidance

Review ABI ownership, status behavior, and whether summary fields match `contracts/pontificate-core-probe-preview-c-abi.md`.

## Activity Log

- 2026-06-08T08:48:00Z - codex - Implemented C ABI probe operation, probe summary buffers, status mapping, compact asset probe field, and ABI tests; validation: `zig build test`, `zig build run`, `cmake -S . -B build`, `cmake --build build`.
