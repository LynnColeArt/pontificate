# Contract: Pontificate Core Editing C ABI

## Purpose

Qt calls timeline editing behavior through the opaque `PontificateProject` handle. The Zig core owns timeline truth; Qt owns presentation state.

## Expected Functions

Names may be refined during implementation, but the ABI should expose these operations:

```c
uint32_t pontificate_project_split_clip(PontificateProject *project, uint32_t clip_index, double split_time);
uint32_t pontificate_project_trim_clip(PontificateProject *project, uint32_t clip_index, double new_timeline_start, double new_source_in, double new_duration);
uint32_t pontificate_project_move_clip(PontificateProject *project, uint32_t clip_index, uint32_t track_index, double timeline_start);
uint32_t pontificate_project_set_clip_opacity_keyframe(PontificateProject *project, uint32_t clip_index, double clip_time, double value);
double pontificate_project_evaluate_clip_opacity(const PontificateProject *project, uint32_t clip_index, double clip_time, uint32_t *status_out);
```

## Status Behavior

- Null handles return `PONTIFICATE_STATUS_NULL_ARGUMENT`.
- Stale or invalid clip indexes return `PONTIFICATE_STATUS_OUT_OF_RANGE`.
- Invalid times, durations, tracks, or keyframe values return `PONTIFICATE_STATUS_INVALID`.
- Missing or unsupported media failures should use the existing specific status codes where relevant.
- Successful mutations return `PONTIFICATE_STATUS_OK`.

## Ownership

The ABI must not return Zig-owned allocations to Qt. Editing functions return status codes. Summary functions continue to use caller-owned buffers.

## Selection Caveat

First-pass functions may address clips by index because the current Qt shell consumes index-based summaries. Qt must refresh selection after split, move, or redraw because ordering can change.
