---
work_package_id: WP01
title: Core Media Asset Model
dependencies: []
requirement_refs:
- FR-001
- FR-003
- FR-004
- NFR-001
- NFR-004
- NFR-005
- C-001
- C-004
tracker_refs: []
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
- T005
agent: codex
history: []
agent_profile: implementer-ivan
authoritative_surface: core/src/media.zig
execution_mode: code_change
model: ''
owned_files:
- core/src/media.zig
role: implementer
tags: []
---

# WP01: Core Media Asset Model

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `codex`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Create the Zig media-library domain model that every later package can depend on. This package owns media assets, media kinds, availability status, extension-based classification, duplicate keys, and import results without touching project persistence, C ABI, or Qt UI.

## Context

Pontificate's current core is a demo module with hardcoded starter clips. The plan moves real project state into Zig while deliberately avoiding decoding, probing, thumbnails, and playback. Keep this file small, deterministic, and easy for `project.zig` to import in WP02.

Implementation command: `spec-kitty agent action implement WP01 --agent <name>`

### Subtask T001: Define Media Asset Types

**Purpose**: Establish the data shape required by FR-001.

**Steps**:
1. Create `core/src/media.zig`.
2. Define `MediaKind` with at least `video`, `audio`, `image`, `subtitle`, and `unknown`.
3. Define `MediaStatus` with at least `available`, `missing`, `unsupported`, and `duplicate`.
4. Define a stable asset identifier representation suitable for serialization by WP02. A simple monotonic integer or string wrapper is acceptable; avoid random IDs unless deterministic tests can control them.
5. Define `MediaAsset` fields for ID, display name, source path, kind, status, optional duration, optional dimensions, and import order or timestamp placeholder.

**Files**: `core/src/media.zig`.

**Validation**: `zig test core/src/media.zig` should compile the type definitions.

### Subtask T002: Classify Media By Extension

**Purpose**: Give imports predictable media kind behavior without adding FFmpeg/GStreamer.

**Steps**:
1. Add a `classifyPath` or similarly named function that accepts a path string.
2. Treat common video extensions as video: `.mp4`, `.mov`, `.mkv`, `.webm`, `.avi`.
3. Treat common audio extensions as audio: `.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`.
4. Treat common image extensions as image: `.png`, `.jpg`, `.jpeg`, `.webp`, `.tif`, `.tiff`.
5. Treat common subtitle extensions as subtitle: `.srt`, `.vtt`, `.ass`.
6. Normalize extension matching to lowercase.
7. Return `unknown` for unknown extensions; do not misclassify unknown media as video.

**Files**: `core/src/media.zig`.

**Validation**: Add table-style tests for representative uppercase/lowercase paths.

### Subtask T003: Derive Display Names And Duplicate Keys

**Purpose**: Make duplicate detection deterministic by normalized source path.

**Steps**:
1. Add a helper that derives a display name from the final path component.
2. Preserve spaces and ordinary Linux path characters in display names.
3. Add a helper that creates a duplicate key from the selected path. This mission can normalize path separators and simple textual identity; do not require realpath because missing files must remain representable.
4. Document in a short comment that deeper canonicalization and relinking belong to later missions.

**Files**: `core/src/media.zig`.

**Validation**: Tests should cover absolute paths, relative-looking strings, paths with spaces, and duplicate key equality for identical paths.

### Subtask T004: Model Import Results And Failure States

**Purpose**: Let project and UI code report failures without crashing.

**Steps**:
1. Define an import result type that distinguishes `imported`, `duplicate`, `missing`, and `unsupported` outcomes.
2. Include enough data for callers to show a visible status: asset ID/index when imported, status code, and short message or enum.
3. Keep result data allocator-safe for Zig callers. C ABI string formatting belongs to WP04.
4. Ensure missing paths can either create an offline asset or return a rejected result according to the project-level policy in WP02; this media module should support both status representations.

**Files**: `core/src/media.zig`.

**Validation**: Unit tests should assert explicit status for unknown extensions and missing/offline representation helpers.

### Subtask T005: Add Focused Media Tests

**Purpose**: Satisfy the core determinism requirement before higher layers use the module.

**Steps**:
1. Add tests for kind classification.
2. Add tests for duplicate-key generation.
3. Add tests for display-name derivation.
4. Add tests for import status/result construction.
5. Keep tests local to `media.zig` so this WP can be verified before `project.zig` exists.

**Files**: `core/src/media.zig`.

**Validation**: Run `zig test core/src/media.zig` and, after WP04 wires modules into the normal build, `zig build test`.

## Definition of Done

- `core/src/media.zig` exists and compiles standalone.
- Media asset, kind, status, and result types cover FR-001, FR-003, and FR-004.
- Extension classification is deterministic and has no external media dependency.
- Unknown extensions do not become video by default.
- Duplicate identity is deterministic by normalized path.
- File paths with spaces are covered by tests.

## Risks

- Overbuilding media probing would violate C-004. Keep this extension-only.
- Real filesystem canonicalization can break missing-media behavior. Store the user-selected path and keep duplicate logic simple.
- Allocator ownership should stay inside Zig domain code; C ABI buffers are WP04's job.

## Reviewer Guidance

Review for deterministic behavior, small API surface, and future compatibility with `project.zig`. Confirm this WP does not touch Qt, C ABI, persistence, playback, thumbnails, or waveform code.
