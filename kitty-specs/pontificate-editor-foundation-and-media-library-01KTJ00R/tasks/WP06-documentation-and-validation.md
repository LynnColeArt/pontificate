---
work_package_id: WP06
title: Documentation And Validation
dependencies:
- WP01
- WP02
- WP03
- WP04
- WP05
requirement_refs:
- FR-011
- NFR-002
- NFR-006
- C-004
- C-005
- C-006
- C-007
- C-008
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-pontificate-editor-foundation-and-media-library-01KTJ00R
base_commit: 58e037d76f60e29973a9b7be53daf0e22dd39c19
created_at: '2026-06-08T05:13:47.459675+00:00'
subtasks:
- T028
- T029
- T030
- T031
- T032
agent: "codex"
shell_pid: "2943638"
history: []
agent_profile: curator-carla
authoritative_surface: docs/
execution_mode: code_change
model: ''
owned_files:
- README.md
- docs/ARCHITECTURE.md
- docs/FEATURES.md
- docs/DISTRIBUTION.md
role: curator
tags: []
---

# WP06: Documentation And Validation

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `curator-carla`
- **Role**: `curator`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Update public docs and run final validation for the first Pontificate editor-foundation mission. This package should document what is now real, keep future ambitions accurately marked as future work, and avoid publishing local agent payloads.

## Context

Pontificate has a big product vision, but this mission only ships media-library, project persistence, core/UI boundary, and initial data-driven timeline behavior. Documentation must be truthful: no playback, export, darkroom, Whisper/subtitles, proxies, thumbnails, or packaging implementation is shipped by this mission.

Implementation command: `spec-kitty agent action implement WP06 --agent <name>`

### Subtask T028: Update README Workflow And Validation

**Purpose**: Make the repo useful to a new contributor after the foundation lands.

**Steps**:
1. Update `README.md` with the current build/run commands.
2. Describe the first real workflow: launch Qt app, import media, see library rows, add asset to timeline, save/load project.
3. Include core CLI inspection usage once WP02 defines the command shape.
4. Keep command examples Linux-first and aligned with Zig 0.16 and Qt 5.
5. Do not claim playback/export/color/subtitle generation as complete.

**Files**: `README.md`.

**Validation**: A reader can follow commands without needing hidden generated files.

### Subtask T029: Update Architecture Documentation

**Purpose**: Record the core/UI split and project model decisions.

**Steps**:
1. Update `docs/ARCHITECTURE.md` to describe Zig ownership of project state, media library, timeline references, and C ABI surface.
2. Document JSON schema v1 at a practical level: project ID/version, assets, tracks, clips.
3. Document reference-based media paths and missing/offline behavior.
4. Document the summary-buffer ABI convention and why Qt does not own project state.
5. Leave space for later FFmpeg/GStreamer probing, playback, color, subtitles, and packaging without implying they are implemented.

**Files**: `docs/ARCHITECTURE.md`.

**Validation**: Architecture docs match implemented APIs and do not overstate scope.

### Subtask T030: Update Feature And Distribution Notes

**Purpose**: Keep product roadmap truthfully separated from shipped behavior.

**Steps**:
1. Update `docs/FEATURES.md` to mark real media library, persistence, data-driven timeline foundation, and validation status.
2. Keep darkroom color, subtitles/Whisper, proxy/render cache, and packaging listed as future work.
3. Update `docs/DISTRIBUTION.md` only to clarify that Flatpak, Snap, and portable executable packaging remain future distribution targets.
4. Avoid promising release artifacts until a packaging mission actually creates them.

**Files**: `docs/FEATURES.md`, `docs/DISTRIBUTION.md`.

**Validation**: Docs distinguish mission-complete from product-complete.

### Subtask T031: Verify Public Repo Hygiene

**Purpose**: Satisfy C-008 before pushing or releasing.

**Steps**:
1. Confirm `.agents/skills/` generated local skill payloads remain ignored.
2. Confirm no local `.worktrees/` content is staged.
3. Check `git status --short --branch` for unexpected files.
4. Do not edit generated local agent skill payloads as part of this WP.

**Files**: `README.md`, `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, `docs/DISTRIBUTION.md`.

**Validation**: `git status --short --branch` only shows intentional docs/source changes.

### Subtask T032: Run Mission Validation Commands

**Purpose**: Prove the foundation works end to end.

**Steps**:
1. Run `zig build test`.
2. Run `zig build run`.
3. Run `cmake -S . -B build`.
4. Run `cmake --build build`.
5. Run `git diff --check`.
6. Record any blocker precisely in the implementation notes if an environment issue prevents validation.

**Files**: `README.md`, `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, `docs/DISTRIBUTION.md`.

**Validation**: All commands pass, or failures are documented with exact causes and residual risk.

## Definition of Done

- README reflects current commands and user workflow.
- Architecture docs describe core-owned media/project/timeline state and C ABI boundaries.
- Feature docs accurately separate shipped foundation from roadmap.
- Distribution docs do not imply packaging has shipped.
- Repo hygiene checks keep generated local agent assets out of public history.
- Final validation commands have been run or blockers are recorded.

## Risks

- Overclaiming roadmap items would mislead contributors. Be strict about what is real.
- Docs can drift from implementation during earlier WPs. Verify against final code, not only the plan.
- Do not put mission task artifacts under WP ownership; Spec Kitty owns `kitty-specs/`.

## Reviewer Guidance

Review for truthfulness, command accuracy, Linux-first wording, and explicit non-goals. Confirm docs do not suggest playback, export, color darkroom, Whisper/subtitles, proxies, thumbnails, or packaging are implemented.

## Activity Log

- 2026-06-08T05:16:50Z – codex – shell_pid=2943638 – Started review via action command
