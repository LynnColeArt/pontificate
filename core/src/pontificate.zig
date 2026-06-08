const std = @import("std");
const media_model = @import("media.zig");
const project_model = @import("project.zig");
const timeline_model = @import("timeline.zig");

pub const media = media_model;
pub const project = project_model;
pub const timeline = timeline_model;

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
        .tracks = @intCast(timeline_model.defaultTracks().len),
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

const abi_allocator = std.heap.smp_allocator;
const default_project_id = "Untitled Project";

pub const AbiStatus = enum(u32) {
    ok = 0,
    null_argument = 1,
    out_of_memory = 2,
    io_error = 3,
    unsupported = 4,
    duplicate = 5,
    missing = 6,
    out_of_range = 7,
    buffer_too_small = 8,
    invalid = 9,
};

const ProjectHandle = struct {
    project: project_model.Project,
};

fn statusCode(status: AbiStatus) u32 {
    return @intFromEnum(status);
}

fn abiIo() std.Io {
    return std.Options.debug_io;
}

fn cString(ptr: ?[*:0]const u8) ?[]const u8 {
    const raw = ptr orelse return null;
    return std.mem.span(raw);
}

fn handleFromOpaque(ptr: ?*anyopaque) ?*ProjectHandle {
    const raw = ptr orelse return null;
    return @ptrCast(@alignCast(raw));
}

fn constHandleFromOpaque(ptr: ?*const anyopaque) ?*const ProjectHandle {
    const raw = ptr orelse return null;
    return @ptrCast(@alignCast(raw));
}

fn statusFromImport(result: media_model.ImportResult) AbiStatus {
    return switch (result) {
        .imported => |value| switch (value.asset.status) {
            .available => .ok,
            .missing => .missing,
            .unsupported => .unsupported,
            .duplicate => .duplicate,
        },
        .duplicate => .duplicate,
        .missing => .missing,
        .unsupported => .unsupported,
    };
}

fn statusFromError(err: anyerror) AbiStatus {
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        error.UnsupportedSchema => .unsupported,
        error.AssetIndexOutOfBounds => .out_of_range,
        error.MissingAsset => .missing,
        error.UnsupportedAsset => .unsupported,
        error.InvalidTrack, error.InvalidTime => .invalid,
        error.NoSpaceLeft => .buffer_too_small,
        else => .io_error,
    };
}

fn writeFormattedCString(
    buffer_ptr: ?[*]u8,
    buffer_len: u32,
    comptime fmt: []const u8,
    args: anytype,
) u32 {
    const raw = buffer_ptr orelse return statusCode(.null_argument);
    const len: usize = @intCast(buffer_len);
    if (len == 0) return statusCode(.buffer_too_small);

    const buffer = raw[0..len];
    const formatted = std.fmt.bufPrint(buffer[0 .. len - 1], fmt, args) catch |err| {
        buffer[0] = 0;
        return statusCode(statusFromError(err));
    };
    buffer[formatted.len] = 0;
    return statusCode(.ok);
}

export fn pontificate_project_create() ?*anyopaque {
    const handle = abi_allocator.create(ProjectHandle) catch return null;
    handle.project = project_model.Project.init(abi_allocator, default_project_id) catch {
        abi_allocator.destroy(handle);
        return null;
    };
    return @ptrCast(handle);
}

export fn pontificate_project_destroy(project_ptr: ?*anyopaque) void {
    const handle = handleFromOpaque(project_ptr) orelse return;
    handle.project.deinit();
    abi_allocator.destroy(handle);
}

export fn pontificate_project_load(path_ptr: ?[*:0]const u8) ?*anyopaque {
    const path = cString(path_ptr) orelse return null;
    const handle = abi_allocator.create(ProjectHandle) catch return null;
    handle.project = project_model.Project.loadFromFile(abi_allocator, abiIo(), path) catch {
        abi_allocator.destroy(handle);
        return null;
    };
    return @ptrCast(handle);
}

export fn pontificate_project_save(project_ptr: ?*const anyopaque, path_ptr: ?[*:0]const u8) u32 {
    const handle = constHandleFromOpaque(project_ptr) orelse return statusCode(.null_argument);
    const path = cString(path_ptr) orelse return statusCode(.null_argument);
    handle.project.saveToFile(abiIo(), path) catch |err| return statusCode(statusFromError(err));
    return statusCode(.ok);
}

export fn pontificate_project_import_path(project_ptr: ?*anyopaque, path_ptr: ?[*:0]const u8) u32 {
    const handle = handleFromOpaque(project_ptr) orelse return statusCode(.null_argument);
    const path = cString(path_ptr) orelse return statusCode(.null_argument);
    const result = handle.project.importPath(abiIo(), path) catch |err| return statusCode(statusFromError(err));
    return statusCode(statusFromImport(result));
}

export fn pontificate_project_asset_count(project_ptr: ?*const anyopaque) u32 {
    const handle = constHandleFromOpaque(project_ptr) orelse return 0;
    return @intCast(@min(handle.project.assets.items.len, std.math.maxInt(u32)));
}

export fn pontificate_project_asset_summary(
    project_ptr: ?*const anyopaque,
    index: u32,
    buffer: ?[*]u8,
    buffer_len: u32,
) u32 {
    const handle = constHandleFromOpaque(project_ptr) orelse return statusCode(.null_argument);
    const asset_index: usize = @intCast(index);
    if (asset_index >= handle.project.assets.items.len) return statusCode(.out_of_range);

    const asset = handle.project.assets.items[asset_index];
    return writeFormattedCString(
        buffer,
        buffer_len,
        "id={d}|kind={s}|status={s}|name={s}|path={s}",
        .{
            asset.id.value,
            @tagName(asset.kind),
            @tagName(asset.status),
            asset.display_name,
            asset.source_path,
        },
    );
}

export fn pontificate_project_add_asset_to_timeline(project_ptr: ?*anyopaque, asset_index: u32) u32 {
    const handle = handleFromOpaque(project_ptr) orelse return statusCode(.null_argument);
    _ = handle.project.addAssetToTimeline(@intCast(asset_index), .{}) catch |err| return statusCode(statusFromError(err));
    return statusCode(.ok);
}

export fn pontificate_project_clip_count(project_ptr: ?*const anyopaque) u32 {
    const handle = constHandleFromOpaque(project_ptr) orelse return 0;
    return @intCast(@min(handle.project.clipCount(), std.math.maxInt(u32)));
}

export fn pontificate_project_clip_summary(
    project_ptr: ?*const anyopaque,
    index: u32,
    buffer: ?[*]u8,
    buffer_len: u32,
) u32 {
    const handle = constHandleFromOpaque(project_ptr) orelse return statusCode(.null_argument);
    const summary = handle.project.clipSummary(@intCast(index)) orelse return statusCode(.out_of_range);
    return writeFormattedCString(
        buffer,
        buffer_len,
        "id={d}|asset_id={d}|track={d}|track_index={d}|start={d:.3}|source_in={d:.3}|duration={d:.3}|opacity={d:.3}|blend={s}|label={s}",
        .{
            summary.clip_id.value,
            summary.asset_id.value,
            summary.track_id.value,
            summary.track_index,
            summary.timeline_start,
            summary.source_in,
            summary.duration,
            summary.opacity,
            @tagName(summary.blend_mode),
            summary.label,
        },
    );
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

fn tmpProjectPathZ(allocator: std.mem.Allocator, tmp: std.testing.TmpDir, path: []const u8) ![:0]u8 {
    return std.fmt.allocPrintSentinel(allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, path }, 0);
}

fn bufferText(buffer: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, buffer, 0) orelse buffer.len;
    return buffer[0..end];
}

test "project C ABI imports summarizes clips and round trips persistence" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "clip.mp4", .data = "fixture" });

    const source_path = try tmpProjectPathZ(std.testing.allocator, tmp, "clip.mp4");
    defer std.testing.allocator.free(source_path);
    const project_path = try tmpProjectPathZ(std.testing.allocator, tmp, "project.json");
    defer std.testing.allocator.free(project_path);

    const handle = pontificate_project_create().?;
    defer pontificate_project_destroy(handle);

    try std.testing.expectEqual(statusCode(.ok), pontificate_project_import_path(handle, source_path.ptr));
    try std.testing.expectEqual(@as(u32, 1), pontificate_project_asset_count(handle));

    var asset_buffer: [512]u8 = undefined;
    try std.testing.expectEqual(
        statusCode(.ok),
        pontificate_project_asset_summary(handle, 0, asset_buffer[0..].ptr, asset_buffer.len),
    );
    try std.testing.expect(std.mem.indexOf(u8, bufferText(&asset_buffer), "name=clip.mp4") != null);

    try std.testing.expectEqual(statusCode(.ok), pontificate_project_add_asset_to_timeline(handle, 0));
    try std.testing.expectEqual(@as(u32, 1), pontificate_project_clip_count(handle));

    var clip_buffer: [512]u8 = undefined;
    try std.testing.expectEqual(
        statusCode(.ok),
        pontificate_project_clip_summary(handle, 0, clip_buffer[0..].ptr, clip_buffer.len),
    );
    const clip_text = bufferText(&clip_buffer);
    try std.testing.expect(std.mem.indexOf(u8, clip_text, "asset_id=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, clip_text, "label=clip.mp4") != null);

    try std.testing.expectEqual(statusCode(.ok), pontificate_project_save(handle, project_path.ptr));

    const loaded = pontificate_project_load(project_path.ptr).?;
    defer pontificate_project_destroy(loaded);
    try std.testing.expectEqual(@as(u32, 1), pontificate_project_asset_count(loaded));
    try std.testing.expectEqual(@as(u32, 1), pontificate_project_clip_count(loaded));
}

test "project C ABI handles nulls ranges and small buffers" {
    try std.testing.expectEqual(statusCode(.null_argument), pontificate_project_import_path(null, null));
    try std.testing.expectEqual(@as(u32, 0), pontificate_project_asset_count(null));

    const handle = pontificate_project_create().?;
    defer pontificate_project_destroy(handle);

    var tiny_buffer: [4]u8 = undefined;
    try std.testing.expectEqual(
        statusCode(.out_of_range),
        pontificate_project_asset_summary(handle, 0, tiny_buffer[0..].ptr, tiny_buffer.len),
    );

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "clip.mp4", .data = "fixture" });
    const source_path = try tmpProjectPathZ(std.testing.allocator, tmp, "clip.mp4");
    defer std.testing.allocator.free(source_path);

    try std.testing.expectEqual(statusCode(.ok), pontificate_project_import_path(handle, source_path.ptr));
    try std.testing.expectEqual(
        statusCode(.buffer_too_small),
        pontificate_project_asset_summary(handle, 0, tiny_buffer[0..].ptr, tiny_buffer.len),
    );
    try std.testing.expectEqual(statusCode(.out_of_range), pontificate_project_add_asset_to_timeline(handle, 99));
}
