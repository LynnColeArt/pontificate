---
work_package_id: WP05
title: Qt Library Import And Timeline Display
dependencies:
- WP04
requirement_refs:
- FR-002
- FR-003
- FR-006
- FR-007
- FR-008
- FR-010
- NFR-002
- NFR-003
- NFR-004
- C-001
- C-002
- C-003
- C-004
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T022
- T023
- T024
- T025
- T026
- T027
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

# WP05: Qt Library Import And Timeline Display

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Replace the Qt shell's hardcoded library and timeline display with data read from the core C ABI. This package owns `ui/src/main.cpp` only and should keep the current Qt 5 Widgets shell simple, launchable, and Linux-first.

## Context

WP04 exposes the project handle and summary functions. This WP should make the first real creator workflow possible: launch, import local files, see library rows, add an asset-backed clip, and preserve timeline zoom while clips come from project state.

Implementation command: `spec-kitty agent action implement WP05 --agent <name>`

### Subtask T022: Own A Core Project Handle In The Qt Shell

**Purpose**: Let the UI present core-owned project state without duplicating it.

**Steps**:
1. Create a small RAII wrapper or local ownership pattern around `PontificateProject *`.
2. Create a new empty project on startup.
3. Destroy the project on application exit.
4. Keep Qt-side state limited to selection, widgets, and presentation state.
5. Surface handle creation failure in the status bar rather than crashing.

**Files**: `ui/src/main.cpp`.

**Validation**: App launches with an empty project and no media files.

### Subtask T023: Add Import Action

**Purpose**: Satisfy FR-002 and SC-001 with a real file-picker workflow.

**Steps**:
1. Add an Import action to the toolbar or menu using Qt 5 APIs.
2. Use `QFileDialog::getOpenFileNames` or equivalent to select one or more local files.
3. Pass selected paths to the C ABI import function.
4. Keep directories out of scope by file dialog configuration or explicit filtering.
5. Report import count, duplicates, missing, unsupported, or failure statuses in the status bar.

**Files**: `ui/src/main.cpp`.

**Validation**: Import three local files in one action and see all accepted rows in the Library panel.

### Subtask T024: Render Library Rows From Core State

**Purpose**: Remove normal dependence on hardcoded starter library items.

**Steps**:
1. Replace the initial `library->addItems(...)` starter list for normal project display.
2. Add a refresh function that reads asset count and asset summaries through the C ABI.
3. Store asset index or ID in each `QListWidgetItem` using Qt item data.
4. Show useful row text with display name, media kind, path, and availability/status when provided by the summary format.
5. Keep empty projects visually valid with an empty list or neutral placeholder that is not a fake asset.

**Files**: `ui/src/main.cpp`.

**Validation**: Duplicate import does not add a second row, and missing/unsupported statuses are visible or reported.

### Subtask T025: Add Asset-To-Timeline UI Path

**Purpose**: Let creators create initial timeline clips from imported media.

**Steps**:
1. Add a simple UI path such as a button, double-click, or context action to add the selected library asset to the timeline.
2. Call the WP04 asset-to-timeline function.
3. Handle invalid selection or failed add with a visible status message.
4. Avoid implementing drag-and-drop polish, trim tools, or ripple editing.

**Files**: `ui/src/main.cpp`.

**Validation**: Select an imported asset, add it to timeline, and see clip count increase.

### Subtask T026: Render Timeline Clips From Core Summaries

**Purpose**: Satisfy FR-008 while preserving the current zoom interaction.

**Steps**:
1. Refactor `TimelineView` so it can clear and repopulate scene clips from model summaries.
2. Keep track lanes and labels stable enough for the current UI.
3. Use clip count and clip summary functions from the C ABI.
4. Derive clip labels and rough widths from project state or summary fields, not hardcoded demo clip names.
5. Preserve `setZoomPercent`, slider behavior, selection, and labels after refresh.

**Files**: `ui/src/main.cpp`.

**Validation**: Timeline zoom still scales horizontally after clips are populated from imported assets.

### Subtask T027: Wire Open/Save Smoke Behavior

**Purpose**: Give the UI enough persistence workflow to exercise WP02/WP04.

**Steps**:
1. Hook Save to a project save dialog and C ABI save function.
2. Hook Open to a project load dialog and replace the current project handle.
3. Refresh Library and Timeline after load.
4. Report load/save errors in the status bar.
5. Keep autosave, recent files, and project bundles out of scope.

**Files**: `ui/src/main.cpp`.

**Validation**: Import media, save project, open it again, and see library state restored. Build with `cmake --build build`.

## Definition of Done

- Qt starts with a real core project handle.
- Import action accepts multiple local files.
- Library rows come from core asset summaries.
- Duplicate/missing/unsupported outcomes are visible or reported.
- A selected asset can become a timeline clip.
- Timeline rendering uses core clip summaries and keeps zoom behavior.
- Open/save dialogs exercise core project persistence.

## Risks

- UI state can accidentally become the source of truth. Keep project data in the core.
- Summary parsing can become brittle. Keep format simple and documented by WP04/WP06.
- Avoid expanding into thumbnails, playback, waveform rendering, drag-and-drop polish, or packaging.

## Reviewer Guidance

Review the Qt/Core boundary, empty-project launch, visible error states, and timeline zoom preservation. Confirm this WP only edits `ui/src/main.cpp`.
