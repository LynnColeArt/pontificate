# Implementation Plan: Media Probe And Preview Foundation

**Branch**: `kitty/mission-media-probe-and-preview-foundation-01KTK4DY` | **Date**: 2026-06-08 | **Spec**: `kitty-specs/media-probe-and-preview-foundation-01KTK4DY/spec.md`
**Input**: Feature specification from `kitty-specs/media-probe-and-preview-foundation-01KTK4DY/spec.md`

## Summary

This mission gives Pontificate its first real media-understanding layer. The Zig core will parse `ffprobe` JSON into typed probe metadata, persist probe status and metadata on assets, expose that state through the C ABI, and use known durations when placing new timeline clips. The Qt shell will show metadata in the Library and add a first-pass preview panel for selected still images or extracted video frames.

The mission deliberately stays below full playback. It does not add a transport clock, render graph, waveform/thumbnail cache, proxy system, native FFmpeg/GStreamer bindings, color pipeline, subtitle editor, or packaged distribution changes. FFmpeg tools are optional runtime helpers: missing `ffprobe` or `ffmpeg` must produce explicit unavailable states while import, save/load, CLI inspection, and Qt launch continue to work.

## Technical Context

**Language/Version**: Zig 0.16.0 for the core, CLI, probe parser, project model, and C ABI; C++17 with Qt 5.15.13 for the desktop shell.
**Primary Dependencies**: Zig standard library, Qt5 Core/Gui/Widgets, CMake 3.28.3, optional Linux runtime `ffprobe` and `ffmpeg` command-line tools. No native FFmpeg, GStreamer, OpenColorIO, GPU, Whisper, font-shaping, database, or cache dependency is introduced.
**Storage**: Local schema-1 JSON project files through `core/src/project.zig`. Probe fields are optional on read for backward compatibility and emitted on write after implementation.
**Testing**: Zig unit tests for probe parsing, metadata defaults, project JSON round trip, old-schema loading, C ABI summary behavior, and duration selection; CLI smoke validation; CMake/Qt build validation; manual or offscreen Qt smoke for image preview and unavailable frame extraction.
**Target Platform**: Linux desktop.
**Project Type**: Native desktop application with a Zig static core library, C ABI header, headless CLI, and Qt Widgets executable.
**Performance Goals**: Probe parsing and project operations remain immediate for small projects. External tool calls run only from explicit probe or preview actions in this first pass; no background scan, persistent cache, playback loop, or repeated decode work is introduced.
**Constraints**: Zig owns project metadata, probe status, persistence, and timeline duration truth. Qt reaches core-owned metadata only through `core/include/pontificate_core.h`. External command invocation must pass paths as arguments and avoid shell interpolation. Preview frame extraction must use temporary files or Qt-owned image loading without mutating project state.
**Scale/Scope**: Early Linux-first editor foundation for small creator projects. The goal is trustworthy metadata and one-frame visual feedback, not production NLE media management.

## Charter Check

The project charter requires predictable changes with clear reviewability, declared language/tool use, Linux-first validation, project-declared quality gates, and consistency between specification, plan, tasks, implementation, and review artifacts.

No charter exception is required. This mission stays inside the declared Zig plus Qt stack, uses optional external tools only as Linux runtime helpers, and keeps observable behavior aligned with documentation.

Re-check before accept:

- `zig build test`
- `zig build run`
- `cmake -S . -B build`
- `cmake --build build`
- `git diff --check`

## Project Structure

### Documentation (this mission)

```
kitty-specs/media-probe-and-preview-foundation-01KTK4DY/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── pontificate-core-probe-preview-c-abi.md
├── tasks.md
└── tasks/
```

### Source Code (repository root)

```
core/
├── include/
│   └── pontificate_core.h
└── src/
    ├── main.zig
    ├── media.zig
    ├── pontificate.zig
    ├── probe.zig
    ├── project.zig
    └── timeline.zig

ui/
└── src/
    └── main.cpp

docs/
├── ARCHITECTURE.md
├── FEATURES.md
└── DISTRIBUTION.md

CMakeLists.txt
build.zig
README.md
```

**Structure Decision**: Keep the current single native application structure. Add `core/src/probe.zig` for the typed parser, process adapter, and probe status mapping. Extend `core/src/media.zig` for metadata value types, `core/src/project.zig` for persistence and clip-duration selection, `core/src/pontificate.zig` plus `core/include/pontificate_core.h` for ABI calls, `core/src/main.zig` for CLI inspection, and `ui/src/main.cpp` for metadata rows and preview controls. Do not split the Qt shell into a larger component tree yet.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Optional FFmpeg process adapter | Linux creators need broad real-world media metadata without writing a decoder stack now. | Extension-derived metadata already exists and is not enough for real durations, dimensions, or stream presence. |
| Optional probe fields in schema-1 JSON | Existing projects from earlier missions lack probe metadata but must remain loadable. | Bumping the schema solely for optional fields would make compatibility worse before the project format needs a breaking change. |
| Dedicated probe metadata summary through C ABI | Qt needs safe access to richer metadata than the current asset row display text. | Having Qt parse project JSON or Zig internals would violate the current core ownership boundary. |
| Qt-owned preview frame extraction | Preview display is UI behavior and should not persist or mutate project media state. | Putting temporary preview files into the project model would create cache semantics this mission explicitly excludes. |

## Architecture And Data Flow

1. Import remains path-based and cheap. It classifies files by extension, records availability, and prevents duplicate paths as it does today.
2. Probe runs through an explicit core project operation. The operation invokes `ffprobe` with argv arguments when available, captures JSON, parses it through `probe.zig`, and stores a normalized result on the asset.
3. Probe parser tests use fixture strings and do not require real media files or installed FFmpeg tools.
4. Probe status is explicit. Assets can be `unprobed`, `available`, `tool_unavailable`, `failed`, `malformed`, or `unsupported`, with optional metadata fields only populated when known.
5. Project save/load writes probe status and metadata when present. Loading older schema-1 JSON uses unprobed defaults and preserves existing media status revalidation.
6. CLI inspection prints probe status, duration, dimensions, frame rate, and stream flags when known.
7. The C ABI exposes an explicit probe operation and a caller-owned-buffer probe summary. Existing asset summaries may include compact metadata, but detailed probe data must be available without returning Zig-owned memory.
8. Qt Library rows refresh from ABI summaries and display known duration, dimensions, frame rate, and stream presence. Unknown and unavailable states are displayed as status, not hidden.
9. Qt preview is display-only:
   - Still images load through Qt image APIs such as `QPixmap` or `QImageReader`.
   - Video preview uses `QProcess` to call `ffmpeg` with argv arguments and extract one frame into a `QTemporaryDir` or `QTemporaryFile`.
   - Failures update the preview panel and status bar without mutating the project.
10. Timeline placement consults the asset metadata when adding new clips. Video and audio assets with known positive durations use that duration; still images and unprobed/offline assets keep existing fallback behavior.

## Data Model Decisions

### Probe Status

Use a dedicated `ProbeStatus` enum distinct from media availability:

- `unprobed`: no probe attempted or old project file lacked probe fields
- `available`: probe succeeded and at least some metadata is trustworthy
- `tool_unavailable`: `ffprobe` was not found or could not run
- `failed`: `ffprobe` ran but returned an error
- `malformed`: output could not be parsed or contradicted expected shapes
- `unsupported`: the asset kind should not be probed in this mission

Reasoning: media availability answers "can the project see the path?" while probe status answers "does the project know real media facts?" Keeping them separate prevents offline files from erasing previously persisted probe metadata.

### Metadata Fields

Store a compact `MediaMetadata` value on each asset:

- optional `duration_seconds`
- optional `dimensions`
- optional `frame_rate`
- `has_video`
- `has_audio`
- `has_subtitles`
- optional `container`
- optional `video_codec`
- optional `audio_codec`

Reasoning: duration, dimensions, frame rate, and stream flags are required now. Codec/container labels are cheap to preserve from `ffprobe` and useful for diagnostics, but they remain display metadata rather than editing logic.

### Probe Timing

Use explicit probe actions for this mission. Do not auto-probe every import yet.

Reasoning: explicit probe keeps import responsive, makes missing-tool behavior easier to understand, and avoids a background-job design before the app has progress/cancel infrastructure. Later missions can add auto-probe-on-import or a queue using the same core operation.

### Existing Clip Durations

Use probed duration for clips created after metadata is known. Do not automatically rewrite existing clips when an asset is probed.

Reasoning: automatic rewrites could surprise users and mutate timeline edits after the fact. A later relink/conform mission can add explicit "update clip from source" behavior.

## C ABI Decision

Add probe-specific functions to `core/include/pontificate_core.h` and implement them in `core/src/pontificate.zig`.

Expected shape:

```c
uint32_t pontificate_project_probe_asset(PontificateProject *project, uint32_t asset_index);
uint32_t pontificate_project_asset_probe_summary(
    const PontificateProject *project,
    uint32_t asset_index,
    char *buffer,
    uint32_t buffer_len);
```

The summary remains caller-owned and NUL-terminated. It should return `PONTIFICATE_STATUS_BUFFER_TOO_SMALL` without partial writes when the buffer is too small. Summary fields can stay pipe-delimited display text for this stage, but the contract should warn callers not to treat arbitrary paths or labels as a stable parser surface.

Status mapping:

- successful probe -> `PONTIFICATE_STATUS_OK`
- invalid project/path/index -> existing null/out-of-range/invalid statuses
- unsupported asset kind -> `PONTIFICATE_STATUS_UNSUPPORTED`
- unavailable tool or failed external process -> `PONTIFICATE_STATUS_IO_ERROR` or `PONTIFICATE_STATUS_UNSUPPORTED`, with the detailed probe status stored in the asset summary

If implementation reveals that process invocation from the C ABI should not block the UI, keep the ABI operation synchronous and make Qt call it only from an explicit user action in this mission. A later job-queue mission can add cancellation and progress.

## Qt Preview Decision

Keep preview frame generation UI-owned in this mission.

- Still images: load selected asset path into a scaled preview label using Qt image loading.
- Videos: invoke `ffmpeg` with `QProcess` and argv arguments, request one frame at a conservative time such as 0.0 seconds or the clip source in-point, write to a temporary image path, load that image into the preview label, and clean it with Qt temporary-file lifetime rules.
- Audio/subtitle/unknown assets: show a clear nonvisual or unsupported preview state.
- Offline or failed extraction: update preview text and the status bar.

Reasoning: the Zig core needs media facts and project truth; Qt needs pixels for display. Avoiding a core preview cache keeps this first slice small and compatible with a later playback/color architecture.

## Testing Strategy

Add Zig tests for:

- successful video `ffprobe` JSON with duration, dimensions, frame rate, video/audio flags, and codec/container labels
- audio-only `ffprobe` JSON with duration and audio flags but no dimensions
- malformed JSON mapped to malformed status
- missing or `N/A` fields defaulting to unknown rather than invented values
- unsupported subtitle or unknown asset kinds producing explicit unsupported probe status
- project JSON write/load preserving probe status and metadata
- old schema-1 JSON without probe fields loading with unprobed metadata defaults
- adding a probed video/audio asset to the timeline using known duration
- adding still image or unprobed assets retaining existing duration fallback
- C ABI probe summary returning buffer-too-small and OK statuses correctly

Add CLI smoke:

```sh
zig build run -- inspect <project-file>
zig build run -- import-save <project-id> <project-file> <media-path>
```

If a new probe CLI command is added, include:

```sh
zig build run -- probe-inspect <project-file>
```

Manual or offscreen Qt smoke:

1. Launch the Qt app.
2. Import a still image and select it.
3. Refresh preview and confirm the image scales into the preview panel.
4. Import a video and probe it when `ffprobe` is installed.
5. Refresh preview when `ffmpeg` is installed and confirm either one frame appears or the UI reports an explicit unavailable/failure state.

Required final commands:

```sh
zig build test
zig build run
cmake -S . -B build
cmake --build build
git diff --check
git status --short --branch
```

## Risks

- Process invocation from Zig 0.16 APIs may need careful wrapper design. Keep it localized in `probe.zig`.
- Blocking probe calls from Qt can freeze the UI if used casually. Limit this mission to explicit user actions and small smoke paths.
- `ffprobe` reports durations and stream metadata inconsistently across codecs. Parser tests must cover missing and `N/A` values.
- Pipe-delimited ABI summaries are display-oriented and can become fragile if they grow. Keep detailed fields short and documented; graduate to structured ABI records later if needed.
- Persisted probe metadata must not be discarded when a file becomes offline after project load.
- Temporary preview files must not leak into the repo or project files.
- Qt preview controls can tempt a playback rewrite. Keep playback, scrubbing, and transport controls out of this mission.

## Implementation Concern Map

### IC-01 - Probe Parser And Status Model

- **Purpose**: Add typed probe result parsing, metadata defaults, status mapping, and deterministic parser tests.
- **Relevant requirements**: FR-001, FR-002, FR-003, NFR-001, NFR-003, NFR-004, C-001, C-002
- **Affected surfaces**: `core/src/probe.zig`, `core/src/media.zig`, `build.zig`
- **Sequencing/depends-on**: none
- **Risks**: Avoid overfitting to one `ffprobe` JSON shape; missing and `N/A` fields must remain unknown.

### IC-02 - Project Persistence And Timeline Duration

- **Purpose**: Store probe metadata on assets, persist it in project JSON, load old files with defaults, and use known duration for new clip placement.
- **Relevant requirements**: FR-003, FR-004, FR-005, FR-012, SC-002, SC-003, SC-009
- **Affected surfaces**: `core/src/media.zig`, `core/src/project.zig`, `core/src/timeline.zig`
- **Sequencing/depends-on**: IC-01
- **Risks**: Revalidating file availability on load must not erase persisted probe metadata.

### IC-03 - Probe Execution And CLI Inspection

- **Purpose**: Add the explicit probe operation, safe `ffprobe` process invocation, and headless inspection output for probe metadata.
- **Relevant requirements**: FR-001, FR-002, FR-007, NFR-003, NFR-004, SC-001, SC-005
- **Affected surfaces**: `core/src/probe.zig`, `core/src/project.zig`, `core/src/main.zig`
- **Sequencing/depends-on**: IC-01, IC-02
- **Risks**: Tool absence must be distinguishable from malformed output and unsupported media.

### IC-04 - C ABI Probe Boundary

- **Purpose**: Expose probe execution and probe summaries through caller-owned buffers for Qt.
- **Relevant requirements**: FR-006, SC-004, C-004
- **Affected surfaces**: `core/include/pontificate_core.h`, `core/src/pontificate.zig`
- **Sequencing/depends-on**: IC-02, IC-03
- **Risks**: Summary text can outgrow fixed buffers; preserve existing buffer-too-small behavior.

### IC-05 - Qt Metadata And Preview Surface

- **Purpose**: Show known metadata in Library rows and display a selected still image or extracted video frame with clear failure feedback.
- **Relevant requirements**: FR-008, FR-009, FR-010, FR-011, SC-006, SC-007, SC-008, NFR-005, NFR-006, NFR-007
- **Affected surfaces**: `ui/src/main.cpp`, `CMakeLists.txt`
- **Sequencing/depends-on**: IC-04 for metadata; still-image preview can be developed alongside the ABI work.
- **Risks**: Keep preview temporary and display-only; do not invent playback or cache semantics.

### IC-06 - Documentation And Validation

- **Purpose**: Update public docs and mission artifacts so shipped probe/preview behavior and non-goals are honest.
- **Relevant requirements**: FR-013, SC-010, SC-011, C-005, C-006, C-007, C-008, C-009, C-010
- **Affected surfaces**: `README.md`, `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, mission quickstart/contracts/data-model
- **Sequencing/depends-on**: IC-01 through IC-05
- **Risks**: Do not present playback, export, color grading, subtitles, thumbnails, waveforms, or packaging as shipped.
