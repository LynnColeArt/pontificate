const std = @import("std");
const media = @import("media.zig");

pub const Seconds = f64;

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

pub const KeyframeProperty = enum {
    opacity,
};

pub const KeyframeInterpolation = enum {
    hold,
    linear,
};

pub const ScalarKeyframe = struct {
    time: Seconds,
    value: f32,
    interpolation: KeyframeInterpolation = .linear,
};

pub const TrackId = struct {
    value: u64,

    pub fn init(value: u64) TrackId {
        return .{ .value = value };
    }
};

pub const ClipId = struct {
    value: u64,

    pub fn init(value: u64) ClipId {
        return .{ .value = value };
    }
};

pub const TimelineTrack = struct {
    id: TrackId,
    index: usize,
    display_name: []const u8,
    kind: TrackKind,
};

pub const TimelineClip = struct {
    id: ClipId,
    asset_id: media.AssetId,
    media_kind: media.MediaKind = .unknown,
    track_id: TrackId,
    track_index: usize,
    timeline_start: Seconds,
    source_in: Seconds = 0.0,
    duration: Seconds,
    opacity: f32 = 1.0,
    blend_mode: BlendMode = .normal,
    opacity_keyframes: []ScalarKeyframe = &.{},
};

pub const ClipSource = struct {
    asset_id: media.AssetId,
    kind: media.MediaKind,
    status: media.MediaStatus,
    display_name: []const u8,
    duration_seconds: ?Seconds = null,
};

pub const ClipPlacement = struct {
    timeline_start: Seconds = 0.0,
    source_in: Seconds = 0.0,
    duration_seconds: ?Seconds = null,
};

pub const ClipTrim = struct {
    timeline_start: Seconds,
    source_in: Seconds,
    duration: Seconds,
};

pub const ClipMove = struct {
    track_index: usize,
    timeline_start: Seconds,
};

pub const ClipSummary = struct {
    clip_id: ClipId,
    asset_id: media.AssetId,
    track_id: TrackId,
    track_index: usize,
    label: []const u8,
    timeline_start: Seconds,
    source_in: Seconds,
    duration: Seconds,
    opacity: f32,
    blend_mode: BlendMode,
};

pub const ClipCreationError = error{
    MissingAsset,
    UnsupportedAsset,
    InvalidTrack,
    InvalidTime,
};

pub const ClipEditError = error{
    ClipIndexOutOfBounds,
    IncompatibleTrack,
    InvalidKeyframe,
};

pub const AddClipError = std.mem.Allocator.Error || ClipCreationError;
pub const EditClipError = std.mem.Allocator.Error || ClipCreationError || ClipEditError;

pub const video_track_id: TrackId = .{ .value = 1 };
pub const audio_track_id: TrackId = .{ .value = 2 };
pub const subtitle_track_id: TrackId = .{ .value = 3 };
pub const grade_track_id: TrackId = .{ .value = 4 };

pub const default_tracks = [_]TimelineTrack{
    .{ .id = video_track_id, .index = 0, .display_name = "V1", .kind = .video },
    .{ .id = audio_track_id, .index = 1, .display_name = "A1", .kind = .audio },
    .{ .id = subtitle_track_id, .index = 2, .display_name = "Titles", .kind = .subtitle },
    .{ .id = grade_track_id, .index = 3, .display_name = "Grade", .kind = .adjustment },
};

pub const Timeline = struct {
    allocator: std.mem.Allocator,
    clips: std.array_list.Managed(TimelineClip),
    next_clip_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) Timeline {
        return .{
            .allocator = allocator,
            .clips = std.array_list.Managed(TimelineClip).init(allocator),
        };
    }

    pub fn deinit(self: *Timeline) void {
        for (self.clips.items) |clip| {
            self.freeKeyframes(clip.opacity_keyframes);
        }
        self.clips.deinit();
        self.* = undefined;
    }

    pub fn tracks(self: Timeline) []const TimelineTrack {
        _ = self;
        return &default_tracks;
    }

    pub fn clipCount(self: Timeline) usize {
        return self.clips.items.len;
    }

    pub fn addAssetClip(
        self: *Timeline,
        source: ClipSource,
        placement: ClipPlacement,
    ) AddClipError!TimelineClip {
        const track = defaultTrackForMediaKind(source.kind) orelse return ClipCreationError.UnsupportedAsset;
        const duration = placement.duration_seconds orelse
            source.duration_seconds orelse
            defaultDurationForMediaKind(source.kind) orelse
            return ClipCreationError.UnsupportedAsset;

        try validateSourceStatus(source.status);
        try validateTimelineTime(placement.timeline_start);
        try validateTimelineTime(placement.source_in);
        try validateClipDuration(duration);

        const clip = TimelineClip{
            .id = ClipId.init(self.next_clip_id),
            .asset_id = source.asset_id,
            .media_kind = source.kind,
            .track_id = track.id,
            .track_index = track.index,
            .timeline_start = placement.timeline_start,
            .source_in = placement.source_in,
            .duration = duration,
        };

        try self.clips.append(clip);
        self.next_clip_id += 1;
        self.sortClips();
        return clip;
    }

    pub fn restoreClip(self: *Timeline, clip: TimelineClip) AddClipError!TimelineClip {
        const track = trackForId(clip.track_id) orelse return ClipCreationError.InvalidTrack;
        if (track.index != clip.track_index) return ClipCreationError.InvalidTrack;

        try validateTimelineTime(clip.timeline_start);
        try validateTimelineTime(clip.source_in);
        try validateClipDuration(clip.duration);

        var restored = clip;
        restored.opacity_keyframes = try self.cloneKeyframes(clip.opacity_keyframes);
        errdefer self.freeKeyframes(restored.opacity_keyframes);

        try self.clips.append(restored);
        self.next_clip_id = @max(self.next_clip_id, clip.id.value + 1);
        self.sortClips();
        return restored;
    }

    pub fn summarizeClipAt(self: Timeline, index: usize, label: []const u8) ?ClipSummary {
        if (index >= self.clips.items.len) return null;
        return summarizeClip(self.clips.items[index], label);
    }

    pub fn splitClip(self: *Timeline, index: usize, split_time: Seconds) EditClipError!TimelineClip {
        const original = try self.clipAt(index);
        try validateTimelineTime(split_time);
        const end_time = original.timeline_start + original.duration;
        if (!(split_time > original.timeline_start and split_time < end_time)) return ClipCreationError.InvalidTime;

        const local_split = split_time - original.timeline_start;
        const left_duration = local_split;
        const right_duration = original.duration - local_split;
        try validateClipDuration(left_duration);
        try validateClipDuration(right_duration);

        var split_keyframes = try self.splitOpacityKeyframes(original.opacity_keyframes, local_split);
        errdefer split_keyframes.deinit(self.allocator);

        var right_clip = original;
        right_clip.id = ClipId.init(self.next_clip_id);
        right_clip.timeline_start = split_time;
        right_clip.source_in = original.source_in + local_split;
        right_clip.duration = right_duration;
        right_clip.opacity_keyframes = split_keyframes.right;

        try self.clips.append(right_clip);

        const old_keyframes = self.clips.items[index].opacity_keyframes;
        self.clips.items[index].duration = left_duration;
        self.clips.items[index].opacity_keyframes = split_keyframes.left;
        split_keyframes.left = &.{};
        split_keyframes.right = &.{};
        self.freeKeyframes(old_keyframes);

        self.next_clip_id += 1;
        self.sortClips();
        return right_clip;
    }

    pub fn trimClip(self: *Timeline, index: usize, trim: ClipTrim) EditClipError!TimelineClip {
        const original = try self.clipAt(index);
        try validateTimelineTime(trim.timeline_start);
        try validateTimelineTime(trim.source_in);
        try validateClipDuration(trim.duration);

        var trimmed_keyframes = try self.constrainOpacityKeyframes(original.opacity_keyframes, trim.duration);
        errdefer self.freeKeyframes(trimmed_keyframes);

        const old_keyframes = self.clips.items[index].opacity_keyframes;
        self.clips.items[index].timeline_start = trim.timeline_start;
        self.clips.items[index].source_in = trim.source_in;
        self.clips.items[index].duration = trim.duration;
        self.clips.items[index].opacity_keyframes = trimmed_keyframes;
        trimmed_keyframes = &.{};
        self.freeKeyframes(old_keyframes);

        const edited = self.clips.items[index];
        self.sortClips();
        return edited;
    }

    pub fn moveClip(self: *Timeline, index: usize, move: ClipMove) EditClipError!TimelineClip {
        const original = try self.clipAt(index);
        const track = trackForIndex(move.track_index) orelse return ClipCreationError.InvalidTrack;
        try validateTimelineTime(move.timeline_start);
        if (!trackCompatibleWithMediaKind(track.kind, original.media_kind)) return ClipEditError.IncompatibleTrack;

        self.clips.items[index].track_id = track.id;
        self.clips.items[index].track_index = track.index;
        self.clips.items[index].timeline_start = move.timeline_start;

        const edited = self.clips.items[index];
        self.sortClips();
        return edited;
    }

    pub fn setScalarKeyframe(
        self: *Timeline,
        index: usize,
        property: KeyframeProperty,
        time: Seconds,
        value: f32,
    ) EditClipError!void {
        return switch (property) {
            .opacity => self.setOpacityKeyframe(index, time, value),
        };
    }

    pub fn setOpacityKeyframe(self: *Timeline, index: usize, time: Seconds, value: f32) EditClipError!void {
        const original = try self.clipAt(index);
        try validateKeyframeTime(time, original.duration);
        try validateOpacityValue(value);

        var next_keyframes = try self.insertOrReplaceKeyframe(original.opacity_keyframes, .{
            .time = time,
            .value = value,
        });
        errdefer self.freeKeyframes(next_keyframes);

        const old_keyframes = self.clips.items[index].opacity_keyframes;
        self.clips.items[index].opacity_keyframes = next_keyframes;
        next_keyframes = &.{};
        self.freeKeyframes(old_keyframes);
    }

    pub fn evaluateOpacityAt(self: Timeline, index: usize, time: Seconds) EditClipError!f32 {
        const clip = try self.clipAt(index);
        try validateKeyframeTime(time, clip.duration);
        if (clip.opacity_keyframes.len == 0) return clip.opacity;
        return evaluateScalarKeyframes(clip.opacity_keyframes, time).?;
    }

    fn clipAt(self: Timeline, index: usize) ClipEditError!TimelineClip {
        if (index >= self.clips.items.len) return ClipEditError.ClipIndexOutOfBounds;
        return self.clips.items[index];
    }

    fn cloneKeyframes(self: Timeline, keyframes: []const ScalarKeyframe) std.mem.Allocator.Error![]ScalarKeyframe {
        if (keyframes.len == 0) return &.{};
        return try self.allocator.dupe(ScalarKeyframe, keyframes);
    }

    fn freeKeyframes(self: Timeline, keyframes: []ScalarKeyframe) void {
        if (keyframes.len > 0) self.allocator.free(keyframes);
    }

    fn splitOpacityKeyframes(
        self: Timeline,
        keyframes: []const ScalarKeyframe,
        local_split: Seconds,
    ) std.mem.Allocator.Error!KeyframeSplit {
        if (keyframes.len == 0) return .{};

        const boundary_value = evaluateScalarKeyframes(keyframes, local_split).?;
        const boundary_interpolation = interpolationForSplitBoundary(keyframes, local_split);
        var left = std.array_list.Managed(ScalarKeyframe).init(self.allocator);
        errdefer left.deinit();
        var right = std.array_list.Managed(ScalarKeyframe).init(self.allocator);
        errdefer right.deinit();

        for (keyframes) |keyframe| {
            if (keyframe.time < local_split) {
                try left.append(keyframe);
            } else if (keyframe.time > local_split) {
                try right.append(.{
                    .time = keyframe.time - local_split,
                    .value = keyframe.value,
                    .interpolation = keyframe.interpolation,
                });
            }
        }

        try left.append(.{ .time = local_split, .value = boundary_value, .interpolation = boundary_interpolation });
        try right.insert(0, .{ .time = 0.0, .value = boundary_value, .interpolation = boundary_interpolation });

        return .{
            .left = try left.toOwnedSlice(),
            .right = try right.toOwnedSlice(),
        };
    }

    fn constrainOpacityKeyframes(
        self: Timeline,
        keyframes: []const ScalarKeyframe,
        duration: Seconds,
    ) std.mem.Allocator.Error![]ScalarKeyframe {
        if (keyframes.len == 0) return &.{};
        const boundary_value = evaluateScalarKeyframes(keyframes, duration).?;
        var constrained = std.array_list.Managed(ScalarKeyframe).init(self.allocator);
        errdefer constrained.deinit();

        for (keyframes) |keyframe| {
            if (keyframe.time < duration) try constrained.append(keyframe);
        }
        try constrained.append(.{ .time = duration, .value = boundary_value });
        return try constrained.toOwnedSlice();
    }

    fn insertOrReplaceKeyframe(
        self: Timeline,
        keyframes: []const ScalarKeyframe,
        keyframe: ScalarKeyframe,
    ) std.mem.Allocator.Error![]ScalarKeyframe {
        var replaced = false;
        const extra: usize = for (keyframes) |existing| {
            if (existing.time == keyframe.time) break 0;
        } else 1;

        const next = try self.allocator.alloc(ScalarKeyframe, keyframes.len + extra);
        var write_index: usize = 0;
        var inserted = false;
        for (keyframes) |existing| {
            if (!inserted and keyframe.time < existing.time) {
                next[write_index] = keyframe;
                write_index += 1;
                inserted = true;
            }
            if (existing.time == keyframe.time) {
                next[write_index] = keyframe;
                replaced = true;
            } else {
                next[write_index] = existing;
            }
            write_index += 1;
        }
        if (!inserted and !replaced) {
            next[write_index] = keyframe;
        }
        return next;
    }

    fn sortClips(self: *Timeline) void {
        std.mem.sort(TimelineClip, self.clips.items, {}, clipLessThan);
    }
};

const KeyframeSplit = struct {
    left: []ScalarKeyframe = &.{},
    right: []ScalarKeyframe = &.{},

    fn deinit(self: KeyframeSplit, allocator: std.mem.Allocator) void {
        if (self.left.len > 0) allocator.free(self.left);
        if (self.right.len > 0) allocator.free(self.right);
    }
};

pub fn empty(allocator: std.mem.Allocator) Timeline {
    return Timeline.init(allocator);
}

pub fn defaultTracks() []const TimelineTrack {
    return &default_tracks;
}

pub fn trackForId(id: TrackId) ?TimelineTrack {
    for (default_tracks) |track| {
        if (track.id.value == id.value) return track;
    }
    return null;
}

pub fn trackForIndex(index: usize) ?TimelineTrack {
    for (default_tracks) |track| {
        if (track.index == index) return track;
    }
    return null;
}

pub fn defaultTrackForMediaKind(kind: media.MediaKind) ?TimelineTrack {
    return switch (kind) {
        .video => default_tracks[0],
        .audio => default_tracks[1],
        .subtitle => default_tracks[2],
        // Stills behave like visual timeline media until a richer still-image
        // duration/editor model exists.
        .image => default_tracks[0],
        .unknown => null,
    };
}

pub fn trackCompatibleWithMediaKind(track_kind: TrackKind, kind: media.MediaKind) bool {
    return switch (kind) {
        .video, .image => track_kind == .video,
        .audio => track_kind == .audio,
        .subtitle => track_kind == .subtitle,
        // Older schema-1 clips do not persist media kind yet. Keep them movable
        // across valid tracks until WP02 teaches project persistence the field.
        .unknown => true,
    };
}

pub fn defaultDurationForMediaKind(kind: media.MediaKind) ?Seconds {
    return switch (kind) {
        .video, .audio => 5.0,
        .image => 5.0,
        .subtitle => 3.0,
        .unknown => null,
    };
}

pub fn evaluateScalarKeyframes(keyframes: []const ScalarKeyframe, at_time: Seconds) ?f32 {
    if (keyframes.len == 0) return null;
    if (keyframes.len == 1 or at_time <= keyframes[0].time) return keyframes[0].value;

    var index: usize = 1;
    while (index < keyframes.len) : (index += 1) {
        const previous = keyframes[index - 1];
        const current = keyframes[index];
        if (at_time == current.time) return current.value;
        if (at_time < current.time) {
            return switch (previous.interpolation) {
                .hold => previous.value,
                .linear => evaluateLinearF32(
                    previous.value,
                    current.value,
                    previous.time,
                    current.time,
                    at_time,
                ),
            };
        }
    }

    return keyframes[keyframes.len - 1].value;
}

fn interpolationForSplitBoundary(keyframes: []const ScalarKeyframe, at_time: Seconds) KeyframeInterpolation {
    var interpolation: KeyframeInterpolation = .linear;
    for (keyframes) |keyframe| {
        if (keyframe.time > at_time) break;
        interpolation = keyframe.interpolation;
    }
    return interpolation;
}

pub fn summarizeClip(clip: TimelineClip, label: []const u8) ClipSummary {
    return .{
        .clip_id = clip.id,
        .asset_id = clip.asset_id,
        .track_id = clip.track_id,
        .track_index = clip.track_index,
        .label = label,
        .timeline_start = clip.timeline_start,
        .source_in = clip.source_in,
        .duration = clip.duration,
        .opacity = clip.opacity,
        .blend_mode = clip.blend_mode,
    };
}

fn validateSourceStatus(status: media.MediaStatus) ClipCreationError!void {
    return switch (status) {
        .available => {},
        .missing => ClipCreationError.MissingAsset,
        .unsupported, .duplicate => ClipCreationError.UnsupportedAsset,
    };
}

fn validateTimelineTime(value: Seconds) ClipCreationError!void {
    if (!std.math.isFinite(value) or !(value >= 0.0)) return ClipCreationError.InvalidTime;
}

fn validateClipDuration(value: Seconds) ClipCreationError!void {
    if (!std.math.isFinite(value) or !(value > 0.0)) return ClipCreationError.InvalidTime;
}

fn validateKeyframeTime(value: Seconds, duration: Seconds) EditClipError!void {
    try validateTimelineTime(value);
    if (value > duration) return ClipEditError.InvalidKeyframe;
}

fn validateOpacityValue(value: f32) EditClipError!void {
    if (!std.math.isFinite(value) or !(value >= 0.0) or !(value <= 1.0)) return ClipEditError.InvalidKeyframe;
}

fn evaluateLinearF32(
    start_value: f32,
    end_value: f32,
    start_time: Seconds,
    end_time: Seconds,
    at_time: Seconds,
) f32 {
    if (end_time <= start_time) return end_value;
    if (at_time <= start_time) return start_value;
    if (at_time >= end_time) return end_value;

    const progress = (at_time - start_time) / (end_time - start_time);
    return start_value + ((end_value - start_value) * @as(f32, @floatCast(progress)));
}

fn clipLessThan(_: void, lhs: TimelineClip, rhs: TimelineClip) bool {
    if (lhs.track_index != rhs.track_index) return lhs.track_index < rhs.track_index;
    if (lhs.timeline_start != rhs.timeline_start) return lhs.timeline_start < rhs.timeline_start;
    return lhs.id.value < rhs.id.value;
}

fn clipSource(
    id: u64,
    kind: media.MediaKind,
    status: media.MediaStatus,
    label: []const u8,
    duration_seconds: ?Seconds,
) ClipSource {
    return .{
        .asset_id = media.AssetId.init(id),
        .kind = kind,
        .status = status,
        .display_name = label,
        .duration_seconds = duration_seconds,
    };
}

test "default timeline has editor tracks and no real clips" {
    var timeline = Timeline.init(std.testing.allocator);
    defer timeline.deinit();

    try std.testing.expectEqual(@as(usize, 4), timeline.tracks().len);
    try std.testing.expectEqualStrings("V1", timeline.tracks()[0].display_name);
    try std.testing.expectEqual(TrackKind.video, timeline.tracks()[0].kind);
    try std.testing.expectEqualStrings("A1", timeline.tracks()[1].display_name);
    try std.testing.expectEqual(TrackKind.audio, timeline.tracks()[1].kind);
    try std.testing.expectEqualStrings("Titles", timeline.tracks()[2].display_name);
    try std.testing.expectEqual(TrackKind.subtitle, timeline.tracks()[2].kind);
    try std.testing.expectEqualStrings("Grade", timeline.tracks()[3].display_name);
    try std.testing.expectEqual(TrackKind.adjustment, timeline.tracks()[3].kind);
    try std.testing.expectEqual(@as(usize, 0), timeline.clipCount());
    try std.testing.expectEqual(@as(u64, 1), timeline.next_clip_id);
}

test "default track selection maps media kinds to timeline layers" {
    try std.testing.expectEqual(video_track_id, defaultTrackForMediaKind(.video).?.id);
    try std.testing.expectEqual(audio_track_id, defaultTrackForMediaKind(.audio).?.id);
    try std.testing.expectEqual(subtitle_track_id, defaultTrackForMediaKind(.subtitle).?.id);
    try std.testing.expectEqual(video_track_id, defaultTrackForMediaKind(.image).?.id);
    try std.testing.expectEqual(@as(?TimelineTrack, null), defaultTrackForMediaKind(.unknown));
    try std.testing.expectEqual(@as(?TimelineTrack, default_tracks[0]), trackForId(video_track_id));
    try std.testing.expectEqual(@as(?TimelineTrack, null), trackForId(TrackId.init(99)));
}

test "asset clips preserve stable media references and defaults" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    const video = try timeline.addAssetClip(
        clipSource(12, .video, .available, "interview.mp4", 8.25),
        .{ .timeline_start = 1.5, .source_in = 0.25 },
    );

    try std.testing.expectEqual(@as(u64, 1), video.id.value);
    try std.testing.expectEqual(@as(u64, 12), video.asset_id.value);
    try std.testing.expectEqual(video_track_id, video.track_id);
    try std.testing.expectEqual(@as(usize, 0), video.track_index);
    try std.testing.expectEqual(@as(Seconds, 1.5), video.timeline_start);
    try std.testing.expectEqual(@as(Seconds, 0.25), video.source_in);
    try std.testing.expectEqual(@as(Seconds, 8.25), video.duration);
    try std.testing.expectEqual(@as(f32, 1.0), video.opacity);
    try std.testing.expectEqual(BlendMode.normal, video.blend_mode);

    const audio = try timeline.addAssetClip(
        clipSource(13, .audio, .available, "dialog.wav", null),
        .{ .timeline_start = 2.0 },
    );

    try std.testing.expectEqual(@as(u64, 2), audio.id.value);
    try std.testing.expectEqual(audio_track_id, audio.track_id);
    try std.testing.expectEqual(@as(Seconds, 5.0), audio.duration);
    try std.testing.expectEqual(@as(usize, 2), timeline.clipCount());
    try std.testing.expectEqual(@as(u64, 3), timeline.next_clip_id);
}

test "asset clip creation handles subtitles and still-image fallback" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    const subtitle = try timeline.addAssetClip(
        clipSource(20, .subtitle, .available, "captions.srt", null),
        .{ .timeline_start = 0.0 },
    );
    const still = try timeline.addAssetClip(
        clipSource(21, .image, .available, "poster.png", null),
        .{ .timeline_start = 3.0, .duration_seconds = 4.0 },
    );

    try std.testing.expectEqual(subtitle_track_id, subtitle.track_id);
    try std.testing.expectEqual(@as(Seconds, 3.0), subtitle.duration);
    try std.testing.expectEqual(video_track_id, still.track_id);
    try std.testing.expectEqual(@as(Seconds, 4.0), still.duration);
}

test "asset clip creation rejects non-renderable sources" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    try std.testing.expectError(
        ClipCreationError.MissingAsset,
        timeline.addAssetClip(clipSource(30, .video, .missing, "offline.mov", null), .{}),
    );
    try std.testing.expectError(
        ClipCreationError.UnsupportedAsset,
        timeline.addAssetClip(clipSource(31, .unknown, .unsupported, "archive.zip", null), .{}),
    );
    try std.testing.expectError(
        ClipCreationError.UnsupportedAsset,
        timeline.addAssetClip(clipSource(32, .video, .duplicate, "duplicate.mp4", null), .{}),
    );
    try std.testing.expectError(
        ClipCreationError.InvalidTime,
        timeline.addAssetClip(clipSource(33, .video, .available, "bad.mov", null), .{ .duration_seconds = 0.0 }),
    );
    try std.testing.expectEqual(@as(usize, 0), timeline.clipCount());
}

test "timeline summaries use caller supplied labels and stable ordering" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(40, .video, .available, "not-used-by-summary.mov", 10.0),
        .{ .timeline_start = 0.0 },
    );
    _ = try timeline.addAssetClip(
        clipSource(41, .audio, .available, "not-used-by-summary.wav", 6.0),
        .{ .timeline_start = 1.25, .source_in = 0.5 },
    );

    const first = timeline.summarizeClipAt(0, "Project Label A").?;
    const second = timeline.summarizeClipAt(1, "Project Label B").?;

    try std.testing.expectEqual(@as(u64, 1), first.clip_id.value);
    try std.testing.expectEqual(@as(u64, 40), first.asset_id.value);
    try std.testing.expectEqualStrings("Project Label A", first.label);
    try std.testing.expectEqual(@as(Seconds, 0.0), first.timeline_start);
    try std.testing.expectEqual(@as(u64, 2), second.clip_id.value);
    try std.testing.expectEqual(@as(u64, 41), second.asset_id.value);
    try std.testing.expectEqualStrings("Project Label B", second.label);
    try std.testing.expectEqual(@as(Seconds, 1.25), second.timeline_start);
    try std.testing.expectEqual(@as(Seconds, 0.5), second.source_in);
    try std.testing.expectEqual(@as(?ClipSummary, null), timeline.summarizeClipAt(2, "missing"));
}

test "timeline restore preserves persisted clip ids and advances id counter" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    const restored = try timeline.restoreClip(.{
        .id = ClipId.init(9),
        .asset_id = media.AssetId.init(44),
        .track_id = video_track_id,
        .track_index = 0,
        .timeline_start = 2.5,
        .source_in = 1.0,
        .duration = 7.0,
        .opacity = 0.75,
        .blend_mode = .screen,
    });

    try std.testing.expectEqual(@as(u64, 9), restored.id.value);
    try std.testing.expectEqual(@as(usize, 1), timeline.clipCount());
    try std.testing.expectEqual(@as(u64, 10), timeline.next_clip_id);
    try std.testing.expectError(
        ClipCreationError.InvalidTrack,
        timeline.restoreClip(.{
            .id = ClipId.init(10),
            .asset_id = media.AssetId.init(45),
            .track_id = TrackId.init(99),
            .track_index = 99,
            .timeline_start = 0.0,
            .duration = 1.0,
        }),
    );
}

test "split clip creates contiguous spans and source in points" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(50, .video, .available, "split.mov", 5.0),
        .{ .timeline_start = 0.0, .source_in = 0.0 },
    );

    const right = try timeline.splitClip(0, 2.0);

    try std.testing.expectEqual(@as(usize, 2), timeline.clipCount());
    try std.testing.expectEqual(@as(u64, 2), right.id.value);

    const left_summary = timeline.summarizeClipAt(0, "left").?;
    const right_summary = timeline.summarizeClipAt(1, "right").?;
    try std.testing.expectEqual(@as(Seconds, 0.0), left_summary.timeline_start);
    try std.testing.expectEqual(@as(Seconds, 0.0), left_summary.source_in);
    try std.testing.expectEqual(@as(Seconds, 2.0), left_summary.duration);
    try std.testing.expectEqual(@as(Seconds, 2.0), right_summary.timeline_start);
    try std.testing.expectEqual(@as(Seconds, 2.0), right_summary.source_in);
    try std.testing.expectEqual(@as(Seconds, 3.0), right_summary.duration);
    try std.testing.expectEqual(@as(u64, 3), timeline.next_clip_id);
}

test "split rejects boundaries and preserves timeline state" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(51, .video, .available, "bad-split.mov", 5.0),
        .{ .timeline_start = 1.0, .source_in = 0.5 },
    );
    const before = timeline.clips.items[0];

    try std.testing.expectError(ClipCreationError.InvalidTime, timeline.splitClip(0, 1.0));
    try std.testing.expectError(ClipCreationError.InvalidTime, timeline.splitClip(0, 6.0));
    try std.testing.expectError(ClipEditError.ClipIndexOutOfBounds, timeline.splitClip(99, 2.0));

    try std.testing.expectEqual(@as(usize, 1), timeline.clipCount());
    try std.testing.expectEqual(before.id, timeline.clips.items[0].id);
    try std.testing.expectEqual(before.timeline_start, timeline.clips.items[0].timeline_start);
    try std.testing.expectEqual(before.source_in, timeline.clips.items[0].source_in);
    try std.testing.expectEqual(before.duration, timeline.clips.items[0].duration);
    try std.testing.expectEqual(@as(u64, 2), timeline.next_clip_id);
}

test "trim clip validates and updates timing atomically" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(52, .video, .available, "trim.mov", 8.0),
        .{ .timeline_start = 0.0, .source_in = 0.0 },
    );

    const trimmed = try timeline.trimClip(0, .{
        .timeline_start = 1.5,
        .source_in = 0.75,
        .duration = 3.25,
    });
    try std.testing.expectEqual(@as(Seconds, 1.5), trimmed.timeline_start);
    try std.testing.expectEqual(@as(Seconds, 0.75), trimmed.source_in);
    try std.testing.expectEqual(@as(Seconds, 3.25), trimmed.duration);

    const before = timeline.clips.items[0];
    try std.testing.expectError(
        ClipCreationError.InvalidTime,
        timeline.trimClip(0, .{ .timeline_start = 0.0, .source_in = 0.0, .duration = 0.0 }),
    );
    try std.testing.expectEqual(before.timeline_start, timeline.clips.items[0].timeline_start);
    try std.testing.expectEqual(before.source_in, timeline.clips.items[0].source_in);
    try std.testing.expectEqual(before.duration, timeline.clips.items[0].duration);
}

test "move clip validates track compatibility and sorts summaries" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(53, .video, .available, "wide.mov", 4.0),
        .{ .timeline_start = 8.0 },
    );
    _ = try timeline.addAssetClip(
        clipSource(54, .video, .available, "b-roll.mov", 4.0),
        .{ .timeline_start = 4.0 },
    );
    _ = try timeline.addAssetClip(
        clipSource(55, .audio, .available, "dialog.wav", 4.0),
        .{ .timeline_start = 4.0 },
    );

    const moved = try timeline.moveClip(1, .{ .track_index = 0, .timeline_start = 1.0 });
    try std.testing.expectEqual(@as(usize, 0), moved.track_index);
    try std.testing.expectEqual(@as(Seconds, 1.0), moved.timeline_start);

    const first = timeline.summarizeClipAt(0, "first").?;
    const second = timeline.summarizeClipAt(1, "second").?;
    const third = timeline.summarizeClipAt(2, "third").?;
    try std.testing.expectEqual(@as(u64, 1), first.clip_id.value);
    try std.testing.expectEqual(@as(u64, 2), second.clip_id.value);
    try std.testing.expectEqual(@as(u64, 3), third.clip_id.value);

    const before_first = timeline.clips.items[0];
    const before_audio = timeline.clips.items[2];
    try std.testing.expectError(
        ClipEditError.IncompatibleTrack,
        timeline.moveClip(2, .{ .track_index = 0, .timeline_start = 2.0 }),
    );
    try std.testing.expectError(
        ClipCreationError.InvalidTrack,
        timeline.moveClip(0, .{ .track_index = 99, .timeline_start = 2.0 }),
    );
    try std.testing.expectError(
        ClipCreationError.InvalidTime,
        timeline.moveClip(0, .{ .track_index = 0, .timeline_start = -1.0 }),
    );
    try std.testing.expectEqual(before_first.track_id, timeline.clips.items[0].track_id);
    try std.testing.expectEqual(before_first.track_index, timeline.clips.items[0].track_index);
    try std.testing.expectEqual(before_first.timeline_start, timeline.clips.items[0].timeline_start);
    try std.testing.expectEqual(before_audio.track_id, timeline.clips.items[2].track_id);
    try std.testing.expectEqual(before_audio.track_index, timeline.clips.items[2].track_index);
    try std.testing.expectEqual(before_audio.timeline_start, timeline.clips.items[2].timeline_start);
}

test "opacity keyframes insert replace sort and evaluate" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(55, .video, .available, "fade.mov", 2.0),
        .{ .timeline_start = 0.0 },
    );

    try timeline.setOpacityKeyframe(0, 1.0, 1.0);
    try timeline.setOpacityKeyframe(0, 0.0, 0.0);
    try timeline.setOpacityKeyframe(0, 1.0, 0.8);

    try std.testing.expectEqual(@as(usize, 2), timeline.clips.items[0].opacity_keyframes.len);
    try std.testing.expectEqual(@as(Seconds, 0.0), timeline.clips.items[0].opacity_keyframes[0].time);
    try std.testing.expectEqual(@as(f32, 0.0), timeline.clips.items[0].opacity_keyframes[0].value);
    try std.testing.expectEqual(@as(Seconds, 1.0), timeline.clips.items[0].opacity_keyframes[1].time);
    try std.testing.expectEqual(@as(f32, 0.8), timeline.clips.items[0].opacity_keyframes[1].value);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), try timeline.evaluateOpacityAt(0, 0.5), 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), try timeline.evaluateOpacityAt(0, 0.0));
    try std.testing.expectEqual(@as(f32, 0.8), try timeline.evaluateOpacityAt(0, 2.0));
}

test "invalid keyframes are rejected without mutation" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(56, .video, .available, "invalid-fade.mov", 2.0),
        .{ .timeline_start = 0.0 },
    );
    try timeline.setScalarKeyframe(0, .opacity, 0.5, 0.5);
    const before = timeline.clips.items[0].opacity_keyframes[0];

    try std.testing.expectError(ClipEditError.InvalidKeyframe, timeline.setOpacityKeyframe(0, 3.0, 0.25));
    try std.testing.expectError(ClipEditError.InvalidKeyframe, timeline.setOpacityKeyframe(0, 1.0, -0.1));
    try std.testing.expectError(ClipEditError.ClipIndexOutOfBounds, timeline.setOpacityKeyframe(9, 1.0, 0.25));

    try std.testing.expectEqual(@as(usize, 1), timeline.clips.items[0].opacity_keyframes.len);
    try std.testing.expectEqual(before.time, timeline.clips.items[0].opacity_keyframes[0].time);
    try std.testing.expectEqual(before.value, timeline.clips.items[0].opacity_keyframes[0].value);
}

test "split and trim preserve keyframe evaluation at new boundaries" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    _ = try timeline.addAssetClip(
        clipSource(57, .video, .available, "keyframed-split.mov", 4.0),
        .{ .timeline_start = 0.0 },
    );
    try timeline.setOpacityKeyframe(0, 0.0, 0.0);
    try timeline.setOpacityKeyframe(0, 4.0, 1.0);

    _ = try timeline.splitClip(0, 2.0);

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), try timeline.evaluateOpacityAt(0, 2.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), try timeline.evaluateOpacityAt(1, 0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), try timeline.evaluateOpacityAt(1, 2.0), 0.0001);

    _ = try timeline.trimClip(1, .{
        .timeline_start = 2.0,
        .source_in = 2.0,
        .duration = 1.0,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), try timeline.evaluateOpacityAt(1, 1.0), 0.0001);
}

test "split preserves hold interpolation across the new boundary" {
    var timeline = empty(std.testing.allocator);
    defer timeline.deinit();

    var keyframes = [_]ScalarKeyframe{
        .{ .time = 0.0, .value = 0.0, .interpolation = .hold },
        .{ .time = 4.0, .value = 1.0, .interpolation = .linear },
    };
    _ = try timeline.restoreClip(.{
        .id = ClipId.init(1),
        .asset_id = media.AssetId.init(58),
        .media_kind = .video,
        .track_id = video_track_id,
        .track_index = 0,
        .timeline_start = 0.0,
        .source_in = 0.0,
        .duration = 4.0,
        .opacity_keyframes = keyframes[0..],
    });
    timeline.next_clip_id = 2;

    _ = try timeline.splitClip(0, 2.0);

    try std.testing.expectEqual(KeyframeInterpolation.hold, timeline.clips.items[1].opacity_keyframes[0].interpolation);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), try timeline.evaluateOpacityAt(1, 1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), try timeline.evaluateOpacityAt(1, 2.0), 0.0001);
}
