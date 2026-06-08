---
work_package_id: WP04
title: Qt Metadata And Preview Surface
dependencies:
- WP03
requirement_refs:
- FR-008
- FR-009
- FR-010
- FR-011
- SC-006
- SC-007
- SC-008
- NFR-005
- NFR-006
- NFR-007
- C-003
- C-004
- C-010
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission live on kitty/mission-media-probe-and-preview-foundation-01KTK4DY. Implementation lanes may branch from dependency-specific bases, but completed changes must merge back into main unless the human redirects the landing branch.
base_branch: kitty/mission-media-probe-and-preview-foundation-01KTK4DY
base_commit: aaf1addbdb767cef83cf2a70d5a4c7b78add5194
created_at: '2026-06-08T08:21:08+00:00'
subtasks:
- T017
- T018
- T019
- T020
- T021
- T022
agent: "codex"
history: []
agent_profile: implementer-ivan
authoritative_surface: ui/src/main.cpp
execution_mode: code_change
model: ''
owned_files:
- ui/src/main.cpp
- CMakeLists.txt
role: implementer
tags: []
---

# Work Package Prompt: WP04 - Qt Metadata And Preview Surface

## Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

## Objective

Display probe metadata in the Library and add a first-pass preview surface for selected still images or extracted video frames.

## Context

WP03 exposes probe metadata through the C ABI. Qt should remain presentation-owned: it displays metadata and temporary preview pixels but does not parse project JSON or mutate core state for preview.

### Subtask T017: Show Metadata In Library Rows

- Read probe summaries through the ABI.
- Add duration, dimensions, frame rate, and stream presence to Library display where known.
- Keep unknown/unavailable states visible but compact.

### Subtask T018: Add Explicit Probe Action

- Provide a clear action for probing the selected asset.
- Refresh the selected row and status bar after probe completes.
- Keep the action synchronous and explicit for this mission.

### Subtask T019: Display Still-Image Preview

- Load selected image assets with Qt image APIs.
- Scale to fit the existing preview panel.
- Do not mutate project state.

### Subtask T020: Extract Video Preview Frame

- Use `QProcess` with argv arguments to invoke `ffmpeg`.
- Write one extracted frame into Qt temporary storage.
- Load the frame into the preview panel and clean up through Qt temporary lifetime rules.

### Subtask T021: Report Failures

- Show clear UI/status feedback for offline files, unsupported kinds, missing `ffmpeg`, nonzero extraction exit, and unreadable temporary images.

### Subtask T022: Keep Build Stable

- Add required Qt includes only.
- Do not add new build dependencies beyond existing Qt modules.
- Validate `cmake -S . -B build` and `cmake --build build`.

## Definition of Done

- Library rows surface known probe metadata.
- Still image preview works.
- Video preview either displays a frame or reports a clear unavailable/failure state.
- Preview does not create persistent cache files or mutate project JSON.

## Reviewer Guidance

Review UI responsiveness, temporary-file handling, path safety in `QProcess`, and whether the preview remains a display-only first pass.
