const std = @import("std");

pub const MediaKind = enum {
    video,
    audio,
    image,
    subtitle,
    unknown,
};

pub const MediaStatus = enum {
    available,
    missing,
    unsupported,
    duplicate,
};

pub const AssetId = struct {
    value: u64,

    pub fn init(value: u64) AssetId {
        return .{ .value = value };
    }
};

pub const Dimensions = struct {
    width: u32,
    height: u32,
};

pub const ProbeStatus = enum {
    unprobed,
    available,
    tool_unavailable,
    failed,
    malformed,
    unsupported,
};

pub const FrameRate = struct {
    numerator: u32,
    denominator: u32,

    pub fn init(numerator: u32, denominator: u32) ?FrameRate {
        if (numerator == 0 or denominator == 0) return null;
        return .{ .numerator = numerator, .denominator = denominator };
    }

    pub fn asFloat(self: FrameRate) f64 {
        return @as(f64, @floatFromInt(self.numerator)) / @as(f64, @floatFromInt(self.denominator));
    }
};

pub const MediaMetadata = struct {
    duration_seconds: ?f64 = null,
    dimensions: ?Dimensions = null,
    frame_rate: ?FrameRate = null,
    has_video: bool = false,
    has_audio: bool = false,
    has_subtitles: bool = false,
    container: ?[]const u8 = null,
    video_codec: ?[]const u8 = null,
    audio_codec: ?[]const u8 = null,

    pub fn deinitOwned(self: *MediaMetadata, allocator: std.mem.Allocator) void {
        if (self.container) |value| allocator.free(value);
        if (self.video_codec) |value| allocator.free(value);
        if (self.audio_codec) |value| allocator.free(value);
        self.* = .{};
    }

    pub fn hasKnownFields(self: MediaMetadata) bool {
        return self.duration_seconds != null or
            self.dimensions != null or
            self.frame_rate != null or
            self.has_video or
            self.has_audio or
            self.has_subtitles or
            self.container != null or
            self.video_codec != null or
            self.audio_codec != null;
    }
};

pub const MediaProbeResult = struct {
    status: ProbeStatus,
    metadata: MediaMetadata = .{},
    message: ?[]const u8 = null,

    pub fn deinitOwned(self: *MediaProbeResult, allocator: std.mem.Allocator) void {
        self.metadata.deinitOwned(allocator);
        if (self.message) |value| allocator.free(value);
        self.* = .{ .status = .unprobed };
    }
};

pub const MediaAsset = struct {
    id: AssetId,
    display_name: []const u8,
    source_path: []const u8,
    kind: MediaKind,
    status: MediaStatus,
    probe_status: ProbeStatus = .unprobed,
    metadata: MediaMetadata = .{},
    duration_seconds: ?f64 = null,
    dimensions: ?Dimensions = null,
    import_order: u64 = 0,

    pub fn fromPath(id: AssetId, source_path: []const u8, import_order: u64) MediaAsset {
        const kind = classifyPath(source_path);
        return .{
            .id = id,
            .display_name = displayNameFromPath(source_path),
            .source_path = source_path,
            .kind = kind,
            .status = statusForKind(kind),
            .import_order = import_order,
        };
    }

    pub fn offline(id: AssetId, source_path: []const u8, import_order: u64) MediaAsset {
        return .{
            .id = id,
            .display_name = displayNameFromPath(source_path),
            .source_path = source_path,
            .kind = classifyPath(source_path),
            .status = .missing,
            .import_order = import_order,
        };
    }
};

pub const DuplicateKey = struct {
    path: []const u8,

    pub fn eql(self: DuplicateKey, other: DuplicateKey) bool {
        if (self.path.len != other.path.len) return false;

        for (self.path, other.path) |left, right| {
            if (normalizedPathByte(left) != normalizedPathByte(right)) return false;
        }

        return true;
    }
};

pub const ImportOutcome = enum {
    imported,
    duplicate,
    missing,
    unsupported,
};

pub const ImportMessage = enum {
    imported,
    duplicate_path,
    missing_path,
    unsupported_kind,
};

pub const ImportedMedia = struct {
    asset: MediaAsset,
    message: ImportMessage = .imported,
};

pub const DuplicateImport = struct {
    source_path: []const u8,
    key: DuplicateKey,
    existing_asset_id: ?AssetId = null,
    status: MediaStatus = .duplicate,
    message: ImportMessage = .duplicate_path,
};

pub const ImportFailure = struct {
    source_path: []const u8,
    status: MediaStatus,
    message: ImportMessage,
};

pub const ImportResult = union(ImportOutcome) {
    imported: ImportedMedia,
    duplicate: DuplicateImport,
    missing: ImportFailure,
    unsupported: ImportFailure,

    pub fn outcome(self: ImportResult) ImportOutcome {
        return std.meta.activeTag(self);
    }

    pub fn status(self: ImportResult) MediaStatus {
        return switch (self) {
            .imported => |value| value.asset.status,
            .duplicate => |value| value.status,
            .missing => |value| value.status,
            .unsupported => |value| value.status,
        };
    }

    pub fn message(self: ImportResult) ImportMessage {
        return switch (self) {
            .imported => |value| value.message,
            .duplicate => |value| value.message,
            .missing => |value| value.message,
            .unsupported => |value| value.message,
        };
    }

    pub fn assetId(self: ImportResult) ?AssetId {
        return switch (self) {
            .imported => |value| value.asset.id,
            .duplicate => |value| value.existing_asset_id,
            .missing, .unsupported => null,
        };
    }
};

pub fn classifyPath(path: []const u8) MediaKind {
    if (extensionEquals(path, ".mp4") or
        extensionEquals(path, ".mov") or
        extensionEquals(path, ".mkv") or
        extensionEquals(path, ".webm") or
        extensionEquals(path, ".avi"))
    {
        return .video;
    }

    if (extensionEquals(path, ".wav") or
        extensionEquals(path, ".mp3") or
        extensionEquals(path, ".flac") or
        extensionEquals(path, ".ogg") or
        extensionEquals(path, ".m4a"))
    {
        return .audio;
    }

    if (extensionEquals(path, ".png") or
        extensionEquals(path, ".jpg") or
        extensionEquals(path, ".jpeg") or
        extensionEquals(path, ".webp") or
        extensionEquals(path, ".tif") or
        extensionEquals(path, ".tiff"))
    {
        return .image;
    }

    if (extensionEquals(path, ".srt") or
        extensionEquals(path, ".vtt") or
        extensionEquals(path, ".ass"))
    {
        return .subtitle;
    }

    return .unknown;
}

pub fn displayNameFromPath(path: []const u8) []const u8 {
    var end = path.len;
    while (end > 0 and isPathSeparator(path[end - 1])) : (end -= 1) {}

    var start = end;
    while (start > 0 and !isPathSeparator(path[start - 1])) : (start -= 1) {}

    return path[start..end];
}

pub fn duplicateKey(path: []const u8) DuplicateKey {
    // Later missions can add realpath/relink canonicalization; WP01 keeps
    // missing files representable by using the selected path text.
    return .{ .path = path };
}

pub fn imported(asset: MediaAsset) ImportResult {
    return .{ .imported = .{ .asset = asset } };
}

pub fn duplicateImport(source_path: []const u8, existing_asset_id: ?AssetId) ImportResult {
    return .{
        .duplicate = .{
            .source_path = source_path,
            .key = duplicateKey(source_path),
            .existing_asset_id = existing_asset_id,
        },
    };
}

pub fn missingImport(source_path: []const u8) ImportResult {
    return .{
        .missing = .{
            .source_path = source_path,
            .status = .missing,
            .message = .missing_path,
        },
    };
}

pub fn unsupportedImport(source_path: []const u8) ImportResult {
    return .{
        .unsupported = .{
            .source_path = source_path,
            .status = .unsupported,
            .message = .unsupported_kind,
        },
    };
}

pub fn statusForKind(kind: MediaKind) MediaStatus {
    return switch (kind) {
        .video, .audio, .image, .subtitle => .available,
        .unknown => .unsupported,
    };
}

fn extensionEquals(path: []const u8, extension: []const u8) bool {
    const dot_index = std.mem.lastIndexOfScalar(u8, path, '.') orelse return false;
    if (dot_index <= lastSeparatorIndex(path)) return false;

    const actual = path[dot_index..];
    if (actual.len != extension.len) return false;

    for (actual, extension) |actual_byte, extension_byte| {
        if (std.ascii.toLower(actual_byte) != extension_byte) return false;
    }

    return true;
}

fn lastSeparatorIndex(path: []const u8) usize {
    var index = path.len;
    while (index > 0) : (index -= 1) {
        if (isPathSeparator(path[index - 1])) return index - 1;
    }

    return 0;
}

fn isPathSeparator(byte: u8) bool {
    return byte == '/' or byte == '\\';
}

fn normalizedPathByte(byte: u8) u8 {
    return if (byte == '\\') '/' else byte;
}

test "classifies common media extensions case insensitively" {
    const cases = [_]struct {
        path: []const u8,
        kind: MediaKind,
    }{
        .{ .path = "/media/Opening Shot.MP4", .kind = .video },
        .{ .path = "cutaways/interview.mov", .kind = .video },
        .{ .path = "mix/voice.FLAC", .kind = .audio },
        .{ .path = "stills/poster.Jpeg", .kind = .image },
        .{ .path = "captions/final.VTT", .kind = .subtitle },
        .{ .path = "notes/readme.txt", .kind = .unknown },
        .{ .path = "folder.with.dot/no_extension", .kind = .unknown },
    };

    for (cases) |case| {
        try std.testing.expectEqual(case.kind, classifyPath(case.path));
    }
}

test "derives display names from Linux-style paths" {
    try std.testing.expectEqualStrings("Opening Shot 01.mp4", displayNameFromPath("/home/lynn/Videos/Opening Shot 01.mp4"));
    try std.testing.expectEqualStrings("relative clip.wav", displayNameFromPath("audio/relative clip.wav"));
    try std.testing.expectEqualStrings("loose-file.srt", displayNameFromPath("loose-file.srt"));
    try std.testing.expectEqualStrings("trailing", displayNameFromPath("/tmp/trailing/"));
}

test "duplicate keys preserve path identity and normalize separators" {
    const first = duplicateKey("/home/lynn/media/clip one.mp4");
    const same = duplicateKey("/home/lynn/media/clip one.mp4");
    const slash_variant = duplicateKey("\\home\\lynn\\media\\clip one.mp4");
    const different = duplicateKey("/home/lynn/media/clip two.mp4");

    try std.testing.expect(first.eql(same));
    try std.testing.expect(first.eql(slash_variant));
    try std.testing.expect(!first.eql(different));
}

test "media asset constructors assign deterministic status" {
    const asset = MediaAsset.fromPath(AssetId.init(7), "/media/B Roll.webm", 3);
    try std.testing.expectEqual(@as(u64, 7), asset.id.value);
    try std.testing.expectEqualStrings("B Roll.webm", asset.display_name);
    try std.testing.expectEqual(MediaKind.video, asset.kind);
    try std.testing.expectEqual(MediaStatus.available, asset.status);
    try std.testing.expectEqual(ProbeStatus.unprobed, asset.probe_status);
    try std.testing.expect(!asset.metadata.hasKnownFields());
    try std.testing.expectEqual(@as(u64, 3), asset.import_order);
    try std.testing.expectEqual(@as(?f64, null), asset.duration_seconds);
    try std.testing.expectEqual(@as(?Dimensions, null), asset.dimensions);

    const unsupported = MediaAsset.fromPath(AssetId.init(8), "/media/unknown.bin", 4);
    try std.testing.expectEqual(MediaKind.unknown, unsupported.kind);
    try std.testing.expectEqual(MediaStatus.unsupported, unsupported.status);
}

test "import results expose visible status without allocation" {
    const asset = MediaAsset.fromPath(AssetId.init(42), "/media/interview.mkv", 1);
    const imported_result = imported(asset);
    try std.testing.expectEqual(ImportOutcome.imported, imported_result.outcome());
    try std.testing.expectEqual(MediaStatus.available, imported_result.status());
    try std.testing.expectEqual(ImportMessage.imported, imported_result.message());
    try std.testing.expectEqual(@as(?AssetId, AssetId.init(42)), imported_result.assetId());

    const duplicate_result = duplicateImport("/media/interview.mkv", AssetId.init(42));
    try std.testing.expectEqual(ImportOutcome.duplicate, duplicate_result.outcome());
    try std.testing.expectEqual(MediaStatus.duplicate, duplicate_result.status());
    try std.testing.expectEqual(ImportMessage.duplicate_path, duplicate_result.message());
    try std.testing.expectEqual(@as(?AssetId, AssetId.init(42)), duplicate_result.assetId());

    const missing_result = missingImport("/offline/missing.mov");
    try std.testing.expectEqual(ImportOutcome.missing, missing_result.outcome());
    try std.testing.expectEqual(MediaStatus.missing, missing_result.status());
    try std.testing.expectEqual(ImportMessage.missing_path, missing_result.message());
    try std.testing.expectEqual(@as(?AssetId, null), missing_result.assetId());

    const unsupported_result = unsupportedImport("/media/archive.zip");
    try std.testing.expectEqual(ImportOutcome.unsupported, unsupported_result.outcome());
    try std.testing.expectEqual(MediaStatus.unsupported, unsupported_result.status());
    try std.testing.expectEqual(ImportMessage.unsupported_kind, unsupported_result.message());
}

test "missing files can also be represented as offline assets" {
    const offline_asset = MediaAsset.offline(AssetId.init(99), "/offline/scene with spaces.srt", 12);
    try std.testing.expectEqual(@as(u64, 99), offline_asset.id.value);
    try std.testing.expectEqualStrings("scene with spaces.srt", offline_asset.display_name);
    try std.testing.expectEqual(MediaKind.subtitle, offline_asset.kind);
    try std.testing.expectEqual(MediaStatus.missing, offline_asset.status);
    try std.testing.expectEqual(ProbeStatus.unprobed, offline_asset.probe_status);
    try std.testing.expect(!offline_asset.metadata.hasKnownFields());
    try std.testing.expectEqual(@as(u64, 12), offline_asset.import_order);
}

test "frame rates reject zero denominators and expose decimal value" {
    try std.testing.expectEqual(@as(?FrameRate, null), FrameRate.init(0, 1));
    try std.testing.expectEqual(@as(?FrameRate, null), FrameRate.init(30000, 0));

    const rate = FrameRate.init(30000, 1001).?;
    try std.testing.expectApproxEqAbs(@as(f64, 29.97002997002997), rate.asFloat(), 0.0000001);
}
