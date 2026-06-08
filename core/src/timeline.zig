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
    track_id: TrackId,
    track_index: usize,
    timeline_start: Seconds,
    source_in: Seconds = 0.0,
    duration: Seconds,
    opacity: f32 = 1.0,
    blend_mode: BlendMode = .normal,
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

pub const AddClipError = std.mem.Allocator.Error || ClipCreationError;

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
            .track_id = track.id,
            .track_index = track.index,
            .timeline_start = placement.timeline_start,
            .source_in = placement.source_in,
            .duration = duration,
        };

        try self.clips.append(clip);
        self.next_clip_id += 1;
        return clip;
    }

    pub fn restoreClip(self: *Timeline, clip: TimelineClip) AddClipError!TimelineClip {
        const track = trackForId(clip.track_id) orelse return ClipCreationError.InvalidTrack;
        if (track.index != clip.track_index) return ClipCreationError.InvalidTrack;

        try validateTimelineTime(clip.timeline_start);
        try validateTimelineTime(clip.source_in);
        try validateClipDuration(clip.duration);

        try self.clips.append(clip);
        self.next_clip_id = @max(self.next_clip_id, clip.id.value + 1);
        return clip;
    }

    pub fn summarizeClipAt(self: Timeline, index: usize, label: []const u8) ?ClipSummary {
        if (index >= self.clips.items.len) return null;
        return summarizeClip(self.clips.items[index], label);
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

pub fn defaultDurationForMediaKind(kind: media.MediaKind) ?Seconds {
    return switch (kind) {
        .video, .audio => 5.0,
        .image => 5.0,
        .subtitle => 3.0,
        .unknown => null,
    };
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
    if (!(value >= 0.0)) return ClipCreationError.InvalidTime;
}

fn validateClipDuration(value: Seconds) ClipCreationError!void {
    if (!(value > 0.0)) return ClipCreationError.InvalidTime;
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
