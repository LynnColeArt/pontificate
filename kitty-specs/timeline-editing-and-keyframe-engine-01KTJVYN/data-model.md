# Data Model: Timeline Editing And Keyframe Engine

## Entities

- **TimelineClip**: A placed segment referencing a media asset. It owns clip ID, asset ID, track ID/index, timeline start, source in-point, duration, opacity, blend mode, and keyframe curves.
- **TimelineEdit**: A validated core mutation such as split, trim, move, or keyframe set. Edits validate all inputs before mutating.
- **TimelineSpan**: The interval `[timeline_start, timeline_start + duration)` occupied by a clip.
- **TrackCompatibility**: Rules that decide which media kinds may be placed on which track kinds.
- **KeyframeProperty**: An animatable property. This mission proves the model with `opacity` and leaves transform, color, subtitle style, blend, grade mix, and transition parameters for later missions.
- **KeyframeValue**: A typed property value. This mission uses scalar values.
- **KeyframeCurve**: Ordered keyframes for one property with replace-on-same-time insertion and linear interpolation.
- **ProjectFile**: JSON project state with schema versioning. New keyframe data is optional on load so older schema-1 files remain usable.

## Decisions

- Same-track overlaps are allowed for now; transition and collision semantics are future work.
- Timeline summaries are deterministic by track, time, and clip ID.
- Invalid split, trim, move, and keyframe operations must fail without partial mutation.
- Media remains reference-based; this mission does not copy, decode, probe, render, thumbnail, proxy, or waveform-generate media.
