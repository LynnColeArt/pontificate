# Data Model: Media Probe And Preview Foundation

## Entities

- **MediaAsset**: Existing imported asset record. This mission extends it with `probe_status` and compact `metadata` while preserving ID, display name, source path, kind, availability status, duration, dimensions, and import order.
- **ProbeStatus**: Metadata-knowledge state for an asset: `unprobed`, `available`, `tool_unavailable`, `failed`, `malformed`, or `unsupported`.
- **MediaMetadata**: Optional media facts from probe output: duration, dimensions, frame rate, stream flags, and display labels for container/video/audio codecs.
- **FrameRate**: Rational or decimal frame-rate value derived from `avg_frame_rate` or related `ffprobe` fields. Unknown or zero denominators stay absent.
- **MediaProbeResult**: Result of a probe attempt, containing status, metadata when successful, and a short display-safe diagnostic when unavailable or failed.
- **PreviewRequest**: Qt-owned request to display an asset or clip preview at a selected time. It does not mutate project state.
- **PreviewFrame**: Temporary image loaded into the Qt preview panel. It is not saved in project JSON and not stored in a persistent cache.
- **ProjectFile**: Schema-1 JSON project representation. Probe fields are optional on read and emitted on write after implementation.

## Field Decisions

### MediaAsset Additions

Expected additions:

- `probe_status: ProbeStatus = .unprobed`
- `metadata: MediaMetadata = .{}`
- optional `probe_message` or diagnostic text if the implementation needs display feedback

Existing `duration_seconds` and `dimensions` may either remain top-level compatibility fields or be folded behind `metadata` while preserving the JSON read/write contract. If both exist during transition, they must be kept consistent.

### MediaMetadata Shape

Expected fields:

- `duration_seconds: ?f64`
- `dimensions: ?Dimensions`
- `frame_rate: ?FrameRate`
- `has_video: bool`
- `has_audio: bool`
- `has_subtitles: bool`
- `container: ?[]const u8`
- `video_codec: ?[]const u8`
- `audio_codec: ?[]const u8`

Unknown values must be absent, not invented. Audio-only media must not receive fake dimensions.

### Project JSON Compatibility

New project writes may include:

```json
{
  "probe_status": "available",
  "metadata": {
    "duration_seconds": 12.5,
    "dimensions": { "width": 1920, "height": 1080 },
    "frame_rate": { "numerator": 30000, "denominator": 1001 },
    "has_video": true,
    "has_audio": true,
    "has_subtitles": false,
    "container": "mov,mp4,m4a,3gp,3g2,mj2",
    "video_codec": "h264",
    "audio_codec": "aac"
  }
}
```

Older schema-1 assets without these fields load as `probe_status = .unprobed` with empty metadata.

## Behavior Rules

- Loading a project may revalidate media availability, but it must not discard persisted metadata.
- A successful probe replaces previous probe metadata for that asset.
- A failed probe updates probe status and diagnostic state without deleting the asset.
- Unsupported subtitle/unknown assets can remain importable when already supported by media kind rules, but their probe status should be explicit.
- New timeline clips use probed positive duration for video/audio assets when known; still-image and unprobed assets use existing fallback duration.
