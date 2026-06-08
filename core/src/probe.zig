const std = @import("std");
const media = @import("media.zig");

pub fn parseFfprobeJson(allocator: std.mem.Allocator, bytes: []const u8) !media.MediaProbeResult {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch {
        return .{ .status = .malformed };
    };
    defer parsed.deinit();

    if (parsed.value != .object) return .{ .status = .malformed };

    var metadata: media.MediaMetadata = .{};
    errdefer metadata.deinitOwned(allocator);

    const root = parsed.value.object;
    if (objectField(root, "format")) |format_value| {
        if (format_value == .object) {
            const format = format_value.object;
            if (numericField(format, "duration")) |duration| {
                if (duration > 0 and std.math.isFinite(duration)) {
                    metadata.duration_seconds = duration;
                }
            }
            if (stringField(format, "format_name")) |container| {
                metadata.container = try duplicateNonEmpty(allocator, container);
            }
        } else {
            return .{ .status = .malformed };
        }
    }

    if (objectField(root, "streams")) |streams_value| {
        if (streams_value != .array) return .{ .status = .malformed };
        for (streams_value.array.items) |stream_value| {
            if (stream_value != .object) continue;
            try mergeStream(allocator, &metadata, stream_value.object);
        }
    }

    return .{ .status = .available, .metadata = metadata };
}

pub fn unsupported(kind: media.MediaKind) media.MediaProbeResult {
    return switch (kind) {
        .video, .audio, .image => .{ .status = .unprobed },
        .subtitle, .unknown => .{ .status = .unsupported },
    };
}

fn mergeStream(
    allocator: std.mem.Allocator,
    metadata: *media.MediaMetadata,
    stream: std.json.ObjectMap,
) !void {
    const codec_type = stringField(stream, "codec_type") orelse return;
    if (std.mem.eql(u8, codec_type, "video")) {
        metadata.has_video = true;
        if (metadata.video_codec == null) {
            if (stringField(stream, "codec_name")) |codec_name| {
                metadata.video_codec = try duplicateNonEmpty(allocator, codec_name);
            }
        }
        const width = intField(stream, "width");
        const height = intField(stream, "height");
        if (width != null and height != null and width.? > 0 and height.? > 0) {
            metadata.dimensions = .{ .width = width.?, .height = height.? };
        }
        if (metadata.frame_rate == null) {
            if (stringField(stream, "avg_frame_rate")) |rate| {
                metadata.frame_rate = parseFrameRate(rate);
            }
        }
        if (metadata.duration_seconds == null) {
            if (numericField(stream, "duration")) |duration| {
                if (duration > 0 and std.math.isFinite(duration)) {
                    metadata.duration_seconds = duration;
                }
            }
        }
    } else if (std.mem.eql(u8, codec_type, "audio")) {
        metadata.has_audio = true;
        if (metadata.audio_codec == null) {
            if (stringField(stream, "codec_name")) |codec_name| {
                metadata.audio_codec = try duplicateNonEmpty(allocator, codec_name);
            }
        }
        if (metadata.duration_seconds == null) {
            if (numericField(stream, "duration")) |duration| {
                if (duration > 0 and std.math.isFinite(duration)) {
                    metadata.duration_seconds = duration;
                }
            }
        }
    } else if (std.mem.eql(u8, codec_type, "subtitle")) {
        metadata.has_subtitles = true;
    }
}

fn objectField(object: std.json.ObjectMap, key: []const u8) ?std.json.Value {
    return object.get(key);
}

fn stringField(object: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = object.get(key) orelse return null;
    return switch (value) {
        .string => |text| if (isUnknownText(text)) null else text,
        .number_string => |text| if (isUnknownText(text)) null else text,
        else => null,
    };
}

fn numericField(object: std.json.ObjectMap, key: []const u8) ?f64 {
    const value = object.get(key) orelse return null;
    return switch (value) {
        .float => |number| number,
        .integer => |number| @floatFromInt(number),
        .number_string => |text| parseFloatText(text),
        .string => |text| parseFloatText(text),
        else => null,
    };
}

fn intField(object: std.json.ObjectMap, key: []const u8) ?u32 {
    const value = object.get(key) orelse return null;
    const integer = switch (value) {
        .integer => |number| number,
        .number_string => |text| std.fmt.parseInt(i64, text, 10) catch return null,
        .string => |text| std.fmt.parseInt(i64, text, 10) catch return null,
        else => return null,
    };
    if (integer <= 0 or integer > std.math.maxInt(u32)) return null;
    return @intCast(integer);
}

fn parseFloatText(text: []const u8) ?f64 {
    if (isUnknownText(text)) return null;
    const parsed = std.fmt.parseFloat(f64, text) catch return null;
    if (!std.math.isFinite(parsed)) return null;
    return parsed;
}

fn parseFrameRate(text: []const u8) ?media.FrameRate {
    if (isUnknownText(text)) return null;
    if (std.mem.indexOfScalar(u8, text, '/')) |slash| {
        const numerator = std.fmt.parseInt(u32, text[0..slash], 10) catch return null;
        const denominator = std.fmt.parseInt(u32, text[slash + 1 ..], 10) catch return null;
        return media.FrameRate.init(numerator, denominator);
    }

    const value = parseFloatText(text) orelse return null;
    if (value <= 0) return null;
    const scaled = @round(value * 1000.0);
    if (scaled <= 0 or scaled > std.math.maxInt(u32)) return null;
    return media.FrameRate.init(@intFromFloat(scaled), 1000);
}

fn isUnknownText(text: []const u8) bool {
    return text.len == 0 or
        std.mem.eql(u8, text, "N/A") or
        std.mem.eql(u8, text, "unknown");
}

fn duplicateNonEmpty(allocator: std.mem.Allocator, text: []const u8) !?[]const u8 {
    if (isUnknownText(text)) return null;
    return try allocator.dupe(u8, text);
}

test "parses video ffprobe metadata" {
    const json =
        \\{
        \\  "format": {
        \\    "duration": "12.500000",
        \\    "format_name": "mov,mp4,m4a,3gp,3g2,mj2"
        \\  },
        \\  "streams": [
        \\    {
        \\      "codec_type": "video",
        \\      "codec_name": "h264",
        \\      "width": 1920,
        \\      "height": 1080,
        \\      "avg_frame_rate": "30000/1001"
        \\    },
        \\    {
        \\      "codec_type": "audio",
        \\      "codec_name": "aac"
        \\    }
        \\  ]
        \\}
    ;

    var result = try parseFfprobeJson(std.testing.allocator, json);
    defer result.deinitOwned(std.testing.allocator);

    try std.testing.expectEqual(media.ProbeStatus.available, result.status);
    try std.testing.expectApproxEqAbs(@as(f64, 12.5), result.metadata.duration_seconds.?, 0.0001);
    try std.testing.expectEqual(media.Dimensions{ .width = 1920, .height = 1080 }, result.metadata.dimensions.?);
    try std.testing.expectEqual(media.FrameRate{ .numerator = 30000, .denominator = 1001 }, result.metadata.frame_rate.?);
    try std.testing.expect(result.metadata.has_video);
    try std.testing.expect(result.metadata.has_audio);
    try std.testing.expect(!result.metadata.has_subtitles);
    try std.testing.expectEqualStrings("mov,mp4,m4a,3gp,3g2,mj2", result.metadata.container.?);
    try std.testing.expectEqualStrings("h264", result.metadata.video_codec.?);
    try std.testing.expectEqualStrings("aac", result.metadata.audio_codec.?);
}

test "parses audio-only metadata without inventing dimensions" {
    const json =
        \\{
        \\  "format": {
        \\    "duration": "3.250000",
        \\    "format_name": "mp3"
        \\  },
        \\  "streams": [
        \\    {
        \\      "codec_type": "audio",
        \\      "codec_name": "mp3"
        \\    }
        \\  ]
        \\}
    ;

    var result = try parseFfprobeJson(std.testing.allocator, json);
    defer result.deinitOwned(std.testing.allocator);

    try std.testing.expectEqual(media.ProbeStatus.available, result.status);
    try std.testing.expectApproxEqAbs(@as(f64, 3.25), result.metadata.duration_seconds.?, 0.0001);
    try std.testing.expectEqual(@as(?media.Dimensions, null), result.metadata.dimensions);
    try std.testing.expect(!result.metadata.has_video);
    try std.testing.expect(result.metadata.has_audio);
    try std.testing.expectEqualStrings("mp3", result.metadata.container.?);
    try std.testing.expectEqualStrings("mp3", result.metadata.audio_codec.?);
}

test "missing and N/A fields stay unknown" {
    const json =
        \\{
        \\  "format": {
        \\    "duration": "N/A",
        \\    "format_name": "matroska,webm"
        \\  },
        \\  "streams": [
        \\    {
        \\      "codec_type": "video",
        \\      "codec_name": "vp9",
        \\      "width": 1280,
        \\      "avg_frame_rate": "0/0"
        \\    },
        \\    {
        \\      "codec_type": "subtitle"
        \\    }
        \\  ]
        \\}
    ;

    var result = try parseFfprobeJson(std.testing.allocator, json);
    defer result.deinitOwned(std.testing.allocator);

    try std.testing.expectEqual(media.ProbeStatus.available, result.status);
    try std.testing.expectEqual(@as(?f64, null), result.metadata.duration_seconds);
    try std.testing.expectEqual(@as(?media.Dimensions, null), result.metadata.dimensions);
    try std.testing.expectEqual(@as(?media.FrameRate, null), result.metadata.frame_rate);
    try std.testing.expect(result.metadata.has_video);
    try std.testing.expect(!result.metadata.has_audio);
    try std.testing.expect(result.metadata.has_subtitles);
    try std.testing.expectEqualStrings("vp9", result.metadata.video_codec.?);
}

test "malformed ffprobe output maps to malformed status" {
    var result = try parseFfprobeJson(std.testing.allocator, "{ this is not json");
    defer result.deinitOwned(std.testing.allocator);

    try std.testing.expectEqual(media.ProbeStatus.malformed, result.status);
    try std.testing.expect(!result.metadata.hasKnownFields());
}

test "unsupported media kinds are explicit" {
    const subtitle = unsupported(.subtitle);
    try std.testing.expectEqual(media.ProbeStatus.unsupported, subtitle.status);

    const unknown = unsupported(.unknown);
    try std.testing.expectEqual(media.ProbeStatus.unsupported, unknown.status);

    const video = unsupported(.video);
    try std.testing.expectEqual(media.ProbeStatus.unprobed, video.status);
}
