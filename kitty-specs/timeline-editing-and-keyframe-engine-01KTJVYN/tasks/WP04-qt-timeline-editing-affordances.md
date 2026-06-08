---
work_package_id: WP04
title: Qt Timeline Editing Affordances
dependencies:
- WP03
requirement_refs:
- FR-011
- NFR-004
- NFR-006
- C-002
- C-003
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T017
- T018
- T019
- T020
agent: codex
history: []
agent_profile: implementer-ivan
authoritative_surface: ui/src/main.cpp
execution_mode: code_change
model: ''
owned_files:
- ui/src/main.cpp
role: implementer
tags: []
---

# Work Package Prompt: WP04 - Qt Timeline Editing Affordances

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Add first-pass Qt controls for selected-clip split, trim, move, and opacity keyframe operations. Keep the UI modest, data-driven, and zoom-preserving.

## Context

`ui/src/main.cpp` currently imports assets, adds them to the timeline, reads summaries through the C ABI, and redraws a `QGraphicsView` timeline. This WP should not become a full drag-editing redesign. It should provide usable controls or menu/toolbar actions that exercise the core edit surface and visibly redraw from core state.

### Subtask T017: Add Clip Selection State

- **Purpose**: Let editing controls target a clip deterministically.
- **Steps**:
  1. Track a selected clip index in the main window or timeline component.
  2. Choose a simple selection affordance, such as selecting the most recently added clip or clicking a clip item if practical.
  3. Refresh or clear selection safely after split/sort/redraw.
- **Files**: Modify `ui/src/main.cpp`.
- **Validation**: App builds and can add a clip without selection crashes.

### Subtask T018: Add Editing Controls

- **Purpose**: Expose split, trim, and move without full drag editing.
- **Steps**:
  1. Add toolbar/menu/inspector controls for split time, trim fields, track/time move fields, or a small equivalent.
  2. Use appropriate Qt widgets already present in the app style, such as spin boxes and buttons.
  3. Wire controls to the C ABI functions from WP03.
  4. Keep status-bar feedback for success/failure.
- **Files**: Modify `ui/src/main.cpp`.
- **Validation**: `cmake --build build`; manual smoke if display is available.

### Subtask T019: Add Opacity Keyframe Control

- **Purpose**: Give a visible path for the first keyframe property.
- **Steps**:
  1. Add a small control for clip-local time and opacity value.
  2. Call the opacity keyframe ABI function.
  3. Optionally evaluate opacity at a chosen time and report the value in the status bar or clip tooltip.
- **Files**: Modify `ui/src/main.cpp`.
- **Validation**: Build succeeds and status messages reflect success/failure.

### Subtask T020: Preserve Zoom And Redraw Cleanly

- **Purpose**: Ensure edit actions do not regress the timeline zoom promise.
- **Steps**:
  1. Keep current zoom percent across refreshes.
  2. Redraw timeline from core summaries after each successful edit.
  3. Keep labels readable enough in the placeholder timeline display.
  4. Avoid blocking media-probe or decode work.
- **Files**: Modify `ui/src/main.cpp`.
- **Validation**: Manual smoke: import asset, add to timeline, zoom, edit, verify zoom remains.

## Definition of Done

- Qt exposes first-pass controls for split/trim/move and opacity keyframes.
- Edit failures report clear status messages.
- Timeline redraw remains core-summary-driven.
- Timeline zoom survives redraw after edit actions.
- `cmake -S . -B build` and `cmake --build build` pass.

## Risks

- Clip selection can become stale after split/sort; refresh carefully.
- Too many controls can clutter the early UI. Keep the surface practical and restrained.
- Qt must not start owning timeline truth.

## Reviewer Guidance

Review whether Qt is still presentation-only, whether status messages are clear, and whether zoom is reapplied after redraw. Build the Qt app and smoke the controls if possible.

Implementation command: `spec-kitty agent action implement WP04 --agent <name>`
