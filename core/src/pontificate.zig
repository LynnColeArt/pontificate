const std = @import("std");

pub const version = "0.0.1";
pub const default_project_summary =
    "4 tracks, 3 starter clips, 2 subtitle cues, keyframed opacity/color/transform";

pub const Time = f64;

pub const Vec2 = struct {
    x: f64,
    y: f64,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,
};

pub const TrackKind = enum {
    video,
    audio,
    subtitle,
    adjustment,
};

pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    overlay,
    soft_light,
    color,
    luminosity,
};

pub const Interpolation = enum {
    hold,
    linear,
    ease_in_out,
};

pub const Keyframe = struct {
    time: Time,
    value: f64,
    interpolation: Interpolation = .linear,
};

pub const SubtitleStyle = struct {
    font_family: []const u8 = "Inter",
    font_size_px: f32 = 42.0,
    fill: Color = .{ .r = 1.0, .g = 1.0, .b = 1.0 },
    stroke: Color = .{ .r = 0.02, .g = 0.02, .b = 0.025 },
    stroke_width_px: f32 = 3.0,
    position: Vec2 = .{ .x = 0.5, .y = 0.86 },
};

pub const SubtitleCue = struct {
    start: Time,
    end: Time,
    text: []const u8,
    style: ?SubtitleStyle = null,
};

pub const Clip = struct {
    id: []const u8,
    name: []const u8,
    track_kind: TrackKind,
    timeline_start: Time,
    duration: Time,
    source_in: Time = 0,
    opacity: []const Keyframe = &.{},
    blend_mode: BlendMode = .normal,
};

pub const Track = struct {
    name: []const u8,
    kind: TrackKind,
};

pub const ProjectStats = struct {
    tracks: u32,
    clips: u32,
    subtitle_cues: u32,
    keyframed_properties: u32,
};

pub const default_tracks = [_]Track{
    .{ .name = "V1", .kind = .video },
    .{ .name = "A1", .kind = .audio },
    .{ .name = "Titles", .kind = .subtitle },
    .{ .name = "Grade", .kind = .adjustment },
};

const fade_in = [_]Keyframe{
    .{ .time = 0.0, .value = 0.0 },
    .{ .time = 1.2, .value = 1.0 },
};

const grade_mix = [_]Keyframe{
    .{ .time = 0.0, .value = 0.65 },
    .{ .time = 8.0, .value = 0.82 },
};

pub const default_clips = [_]Clip{
    .{
        .id = "clip-video-001",
        .name = "Opening shot",
        .track_kind = .video,
        .timeline_start = 0.0,
        .duration = 8.0,
        .opacity = &fade_in,
    },
    .{
        .id = "clip-audio-001",
        .name = "Camera audio",
        .track_kind = .audio,
        .timeline_start = 0.0,
        .duration = 8.0,
    },
    .{
        .id = "clip-grade-001",
        .name = "Darkroom grade",
        .track_kind = .adjustment,
        .timeline_start = 0.0,
        .duration = 8.0,
        .opacity = &grade_mix,
        .blend_mode = .soft_light,
    },
};

pub const default_subtitles = [_]SubtitleCue{
    .{ .start = 0.4, .end = 2.6, .text = "A caption is editable media." },
    .{ .start = 3.1, .end = 5.8, .text = "Style can cascade globally or locally." },
};

pub fn defaultProjectStats() ProjectStats {
    return .{
        .tracks = default_tracks.len,
        .clips = default_clips.len,
        .subtitle_cues = default_subtitles.len,
        .keyframed_properties = 3,
    };
}

pub fn evaluateLinear(
    start_value: f64,
    end_value: f64,
    start_time: Time,
    end_time: Time,
    at_time: Time,
) f64 {
    if (end_time <= start_time) return end_value;
    if (at_time <= start_time) return start_value;
    if (at_time >= end_time) return end_value;

    const progress = (at_time - start_time) / (end_time - start_time);
    return start_value + ((end_value - start_value) * progress);
}

pub fn evaluateKeyframes(frames: []const Keyframe, at_time: Time) ?f64 {
    if (frames.len == 0) return null;
    if (frames.len == 1 or at_time <= frames[0].time) return frames[0].value;

    var index: usize = 1;
    while (index < frames.len) : (index += 1) {
        const previous = frames[index - 1];
        const current = frames[index];

        if (at_time <= current.time) {
            return switch (previous.interpolation) {
                .hold => previous.value,
                .linear, .ease_in_out => evaluateLinear(
                    previous.value,
                    current.value,
                    previous.time,
                    current.time,
                    at_time,
                ),
            };
        }
    }

    return frames[frames.len - 1].value;
}

export fn pontificate_version() [*:0]const u8 {
    return version.ptr;
}

export fn pontificate_default_project_summary() [*:0]const u8 {
    return default_project_summary.ptr;
}

export fn pontificate_default_track_count() u32 {
    return defaultProjectStats().tracks;
}

export fn pontificate_default_clip_count() u32 {
    return defaultProjectStats().clips;
}

export fn pontificate_default_subtitle_cue_count() u32 {
    return defaultProjectStats().subtitle_cues;
}

export fn pontificate_evaluate_keyframe_linear(
    start_value: f64,
    end_value: f64,
    start_time: f64,
    end_time: f64,
    at_time: f64,
) f64 {
    return evaluateLinear(start_value, end_value, start_time, end_time, at_time);
}

test "linear keyframes interpolate and clamp" {
    try std.testing.expectEqual(@as(f64, 0.0), evaluateLinear(0, 1, 10, 20, 5));
    try std.testing.expectEqual(@as(f64, 0.5), evaluateLinear(0, 1, 10, 20, 15));
    try std.testing.expectEqual(@as(f64, 1.0), evaluateLinear(0, 1, 10, 20, 25));
}

test "keyframe evaluator returns surrounding values" {
    const frames = [_]Keyframe{
        .{ .time = 0, .value = 10 },
        .{ .time = 10, .value = 30 },
        .{ .time = 20, .value = 20 },
    };

    try std.testing.expectEqual(@as(?f64, 10), evaluateKeyframes(&frames, -1));
    try std.testing.expectEqual(@as(?f64, 20), evaluateKeyframes(&frames, 5));
    try std.testing.expectEqual(@as(?f64, 25), evaluateKeyframes(&frames, 15));
    try std.testing.expectEqual(@as(?f64, 20), evaluateKeyframes(&frames, 30));
}

test "default project starts with first-class subtitles" {
    const stats = defaultProjectStats();

    try std.testing.expectEqual(@as(u32, 4), stats.tracks);
    try std.testing.expectEqual(@as(u32, 3), stats.clips);
    try std.testing.expectEqual(@as(u32, 2), stats.subtitle_cues);
}
