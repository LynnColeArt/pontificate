---
work_package_id: WP05
title: Documentation Validation And Acceptance Notes
dependencies:
- WP04
requirement_refs:
- FR-013
- SC-010
- SC-011
- NFR-002
- C-005
- C-006
- C-007
- C-008
- C-009
- C-010
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission live on kitty/mission-media-probe-and-preview-foundation-01KTK4DY. Implementation lanes may branch from dependency-specific bases, but completed changes must merge back into main unless the human redirects the landing branch.
base_branch: kitty/mission-media-probe-and-preview-foundation-01KTK4DY
base_commit: aaf1addbdb767cef83cf2a70d5a4c7b78add5194
created_at: '2026-06-08T08:21:08+00:00'
subtasks:
- T023
- T024
- T025
- T026
agent: "codex"
history: []
agent_profile: implementer-ivan
authoritative_surface: README.md
execution_mode: code_change
model: ''
owned_files:
- README.md
- docs/**
- kitty-specs/media-probe-and-preview-foundation-01KTK4DY/**
role: implementer
tags: []
---

# Work Package Prompt: WP05 - Documentation Validation And Acceptance Notes

## Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

## Objective

Align public docs and mission evidence with the shipped probe/preview foundation, then run and record final validation.

## Context

Earlier WPs implement behavior. This WP prevents product overclaiming and gives future contributors a clear handoff for playback, caching, color, subtitles, and packaging.

### Subtask T023: Update Shipped Behavior Docs

- Update `README.md` and `docs/FEATURES.md` for probe metadata, Library display, first-pass preview, and probed timeline duration.
- Update architecture docs if they describe core/project/UI responsibilities.

### Subtask T024: Document Non-Goals

- Clearly keep playback, export, thumbnails, waveforms, proxies, persistent caches, color darkroom, subtitles, Whisper, fonts, and packaging out of shipped scope.

### Subtask T025: Record Validation Evidence

- Capture the validation commands run and any caveats in mission artifacts.
- Include unavailable FFmpeg behavior if tools are not installed.

### Subtask T026: Final Validation

- Run `zig build test`.
- Run `zig build run`.
- Run `cmake -S . -B build`.
- Run `cmake --build build`.
- Run `git diff --check`.
- Check `git status --short --branch`.

## Definition of Done

- Docs match implemented behavior and non-goals.
- Validation commands pass or any failure is explained with actionable detail.
- Mission artifacts are ready for accept/review.

## Reviewer Guidance

Review for overclaiming. This mission ships metadata and still/frame preview, not playback, export, color grading, subtitle editing, or packaged distribution.

## Activity Log

- 2026-06-08T09:04:00Z - codex - Updated README, architecture, and feature docs for shipped probe/preview behavior and non-goals; recorded validation evidence in quickstart; validation: `zig build test`, `zig build run`, `cmake -S . -B build`, `cmake --build build`, `git diff --check`.
