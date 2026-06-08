# Contract: Pontificate Core Probe And Preview C ABI

## Purpose

Qt must access core-owned probe metadata through the opaque `PontificateProject` handle. The Zig core owns asset metadata, probe status, persistence, and timeline duration decisions. Qt owns preview display and temporary video-frame extraction.

## Expected Functions

Names may be refined during implementation, but the ABI should expose these operations:

```c
uint32_t pontificate_project_probe_asset(PontificateProject *project, uint32_t asset_index);
uint32_t pontificate_project_asset_probe_summary(
    const PontificateProject *project,
    uint32_t asset_index,
    char *buffer,
    uint32_t buffer_len);
```

Existing asset summaries may also include compact metadata fields if useful for the Library row.

## Summary Fields

The probe summary should be NUL-terminated UTF-8 display text in caller-owned storage. Expected pipe-delimited fields:

```text
probe_status=available|duration=12.500|dimensions=1920x1080|frame_rate=29.970|has_video=true|has_audio=true|has_subtitles=false|container=mov,mp4,m4a,3gp,3g2,mj2|video_codec=h264|audio_codec=aac
```

Unknown values should be represented explicitly, such as `duration=unknown` or omitted only when the contract documents omission.

## Status Behavior

- Null project or buffer pointers return `PONTIFICATE_STATUS_NULL_ARGUMENT`.
- Invalid asset indexes return `PONTIFICATE_STATUS_OUT_OF_RANGE`.
- Unsupported asset kinds return `PONTIFICATE_STATUS_UNSUPPORTED` and store/report an unsupported probe status.
- Missing tools or failed external processes return a status compatible with existing error codes while storing/reporting the detailed probe status.
- Too-small buffers return `PONTIFICATE_STATUS_BUFFER_TOO_SMALL` without writing a partial summary.
- Successful summaries and successful probe operations return `PONTIFICATE_STATUS_OK`.

## Ownership

The ABI must not return Zig-owned allocations to Qt. Qt provides all output buffers. Qt may parse summary fields for display, but this pipe-delimited text remains a display-oriented v1 surface, not the final structured metadata ABI.

## Preview Boundary

No core ABI is required for preview frame pixels in this mission. Qt loads still images directly and may invoke `ffmpeg` via `QProcess` to generate a temporary frame for video preview. Preview failures must not mutate the project.
