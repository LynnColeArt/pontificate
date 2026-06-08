const std = @import("std");
const media = @import("media.zig");
const timeline_model = @import("timeline.zig");

pub const schema_version: u32 = 1;
pub const max_project_file_bytes: usize = 4 * 1024 * 1024;

pub const ProjectError = error{
    UnsupportedSchema,
    AssetIndexOutOfBounds,
};

pub const ProjectEditError = timeline_model.EditClipError;

pub const Project = struct {
    allocator: std.mem.Allocator,
    id: []u8,
    assets: std.array_list.Managed(media.MediaAsset),
    timeline: timeline_model.Timeline,
    next_asset_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Project {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .assets = std.array_list.Managed(media.MediaAsset).init(allocator),
            .timeline = timeline_model.Timeline.init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        self.timeline.deinit();
        for (self.assets.items) |asset| {
            self.allocator.free(asset.display_name);
            self.allocator.free(asset.source_path);
        }
        self.assets.deinit();
        self.allocator.free(self.id);
        self.* = undefined;
    }

    pub fn importPath(self: *Project, io: std.Io, source_path: []const u8) !media.ImportResult {
        const kind = media.classifyPath(source_path);
        if (kind == .unknown) return media.unsupportedImport(source_path);

        const selected_key = media.duplicateKey(source_path);
        for (self.assets.items) |asset| {
            if (media.duplicateKey(asset.source_path).eql(selected_key)) {
                return media.duplicateImport(source_path, asset.id);
            }
        }

        const status: media.MediaStatus = if (pathExists(io, source_path)) .available else .missing;
        const source_copy = try self.allocator.dupe(u8, source_path);
        errdefer self.allocator.free(source_copy);

        const display_copy = try self.allocator.dupe(u8, media.displayNameFromPath(source_copy));
        errdefer self.allocator.free(display_copy);

        const asset = media.MediaAsset{
            .id = media.AssetId.init(self.next_asset_id),
            .display_name = display_copy,
            .source_path = source_copy,
            .kind = kind,
            .status = status,
            .import_order = self.assets.items.len,
        };
        try self.assets.append(asset);
        self.next_asset_id += 1;

        return media.imported(asset);
    }

    pub fn writeJson(self: Project, writer: *std.Io.Writer) !void {
        var json: std.json.Stringify = .{
            .writer = writer,
            .options = .{ .whitespace = .indent_2 },
        };

        try json.beginObject();
        try json.objectField("schema_version");
        try json.write(schema_version);
        try json.objectField("project_id");
        try json.write(self.id);
        try json.objectField("assets");
        try json.beginArray();
        for (self.assets.items) |asset| {
            try json.beginObject();
            try json.objectField("id");
            try json.write(asset.id.value);
            try json.objectField("display_name");
            try json.write(asset.display_name);
            try json.objectField("source_path");
            try json.write(asset.source_path);
            try json.objectField("kind");
            try json.write(asset.kind);
            try json.objectField("status");
            try json.write(asset.status);
            try json.objectField("duration_seconds");
            try json.write(asset.duration_seconds);
            try json.objectField("dimensions");
            try json.write(asset.dimensions);
            try json.objectField("import_order");
            try json.write(asset.import_order);
            try json.endObject();
        }
        try json.endArray();
        try json.objectField("timeline");
        try json.beginObject();
        try json.objectField("tracks");
        try json.beginArray();
        for (self.timeline.tracks()) |track| {
            try json.beginObject();
            try json.objectField("id");
            try json.write(track.id.value);
            try json.objectField("index");
            try json.write(track.index);
            try json.objectField("display_name");
            try json.write(track.display_name);
            try json.objectField("kind");
            try json.write(track.kind);
            try json.endObject();
        }
        try json.endArray();
        try json.objectField("clips");
        try json.beginArray();
        for (self.timeline.clips.items) |clip| {
            try json.beginObject();
            try json.objectField("id");
            try json.write(clip.id.value);
            try json.objectField("asset_id");
            try json.write(clip.asset_id.value);
            try json.objectField("media_kind");
            try json.write(clip.media_kind);
            try json.objectField("track_id");
            try json.write(clip.track_id.value);
            try json.objectField("track_index");
            try json.write(clip.track_index);
            try json.objectField("timeline_start");
            try json.write(clip.timeline_start);
            try json.objectField("source_in");
            try json.write(clip.source_in);
            try json.objectField("duration");
            try json.write(clip.duration);
            try json.objectField("opacity");
            try json.write(clip.opacity);
            try json.objectField("blend_mode");
            try json.write(clip.blend_mode);
            try json.objectField("opacity_keyframes");
            try json.beginArray();
            for (clip.opacity_keyframes) |keyframe| {
                try json.beginObject();
                try json.objectField("time");
                try json.write(keyframe.time);
                try json.objectField("value");
                try json.write(keyframe.value);
                try json.objectField("interpolation");
                try json.write(keyframe.interpolation);
                try json.endObject();
            }
            try json.endArray();
            try json.endObject();
        }
        try json.endArray();
        try json.endObject();
        try json.endObject();
    }

    pub fn toOwnedJson(self: Project, allocator: std.mem.Allocator) ![]u8 {
        var out: std.Io.Writer.Allocating = .init(allocator);
        errdefer out.deinit();
        try self.writeJson(&out.writer);
        return out.toOwnedSlice();
    }

    pub fn saveToFile(self: Project, io: std.Io, path: []const u8) !void {
        const bytes = try self.toOwnedJson(self.allocator);
        defer self.allocator.free(bytes);
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Project {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_project_file_bytes));
        defer allocator.free(bytes);
        return loadFromSlice(allocator, io, bytes);
    }

    pub fn loadFromSlice(allocator: std.mem.Allocator, io: std.Io, bytes: []const u8) !Project {
        var parsed = try std.json.parseFromSlice(SerializedProject, allocator, bytes, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.schema_version != schema_version) return ProjectError.UnsupportedSchema;

        var project = try Project.init(allocator, parsed.value.project_id);
        errdefer project.deinit();

        var max_id: u64 = 0;
        for (parsed.value.assets) |asset| {
            const source_copy = try allocator.dupe(u8, asset.source_path);
            errdefer allocator.free(source_copy);

            const display_copy = try allocator.dupe(u8, asset.display_name);
            errdefer allocator.free(display_copy);

            const loaded_status = revalidatedStatus(io, source_copy, asset.kind, asset.status);
            const loaded_asset = media.MediaAsset{
                .id = media.AssetId.init(asset.id),
                .display_name = display_copy,
                .source_path = source_copy,
                .kind = asset.kind,
                .status = loaded_status,
                .duration_seconds = asset.duration_seconds,
                .dimensions = asset.dimensions,
                .import_order = asset.import_order,
            };

            try project.assets.append(loaded_asset);
            max_id = @max(max_id, asset.id);
        }

        project.next_asset_id = max_id + 1;

        for (parsed.value.timeline.clips) |clip| {
            const asset_id = media.AssetId.init(clip.asset_id);
            const restored_media_kind = if (clip.media_kind == .unknown)
                (project.assetById(asset_id) orelse return ProjectError.AssetIndexOutOfBounds).kind
            else
                clip.media_kind;
            const keyframes = try ownedOpacityKeyframesFromSerialized(allocator, clip.opacity_keyframes, clip.duration);
            defer if (keyframes.len > 0) allocator.free(keyframes);

            _ = try project.timeline.restoreClip(.{
                .id = timeline_model.ClipId.init(clip.id),
                .asset_id = asset_id,
                .media_kind = restored_media_kind,
                .track_id = timeline_model.TrackId.init(clip.track_id),
                .track_index = clip.track_index,
                .timeline_start = clip.timeline_start,
                .source_in = clip.source_in,
                .duration = clip.duration,
                .opacity = clip.opacity,
                .blend_mode = clip.blend_mode,
                .opacity_keyframes = keyframes,
            });
        }

        return project;
    }

    pub fn addAssetToTimeline(
        self: *Project,
        asset_index: usize,
        placement: timeline_model.ClipPlacement,
    ) !timeline_model.TimelineClip {
        if (asset_index >= self.assets.items.len) return ProjectError.AssetIndexOutOfBounds;
        const asset = self.assets.items[asset_index];
        return self.timeline.addAssetClip(.{
            .asset_id = asset.id,
            .kind = asset.kind,
            .status = asset.status,
            .display_name = asset.display_name,
            .duration_seconds = asset.duration_seconds,
        }, placement);
    }

    pub fn splitClip(self: *Project, clip_index: usize, split_time: timeline_model.Seconds) ProjectEditError!timeline_model.TimelineClip {
        return self.timeline.splitClip(clip_index, split_time);
    }

    pub fn trimClip(
        self: *Project,
        clip_index: usize,
        trim: timeline_model.ClipTrim,
    ) ProjectEditError!timeline_model.TimelineClip {
        return self.timeline.trimClip(clip_index, trim);
    }

    pub fn moveClip(
        self: *Project,
        clip_index: usize,
        move: timeline_model.ClipMove,
    ) ProjectEditError!timeline_model.TimelineClip {
        return self.timeline.moveClip(clip_index, move);
    }

    pub fn setClipOpacityKeyframe(
        self: *Project,
        clip_index: usize,
        time: timeline_model.Seconds,
        value: f32,
    ) ProjectEditError!void {
        return self.timeline.setOpacityKeyframe(clip_index, time, value);
    }

    pub fn evaluateClipOpacity(
        self: Project,
        clip_index: usize,
        time: timeline_model.Seconds,
    ) ProjectEditError!f32 {
        return self.timeline.evaluateOpacityAt(clip_index, time);
    }

    pub fn clipCount(self: Project) usize {
        return self.timeline.clipCount();
    }

    pub fn clipSummary(self: Project, index: usize) ?timeline_model.ClipSummary {
        if (index >= self.timeline.clips.items.len) return null;
        const clip = self.timeline.clips.items[index];
        const asset = self.assetById(clip.asset_id) orelse return null;
        return timeline_model.summarizeClip(clip, asset.display_name);
    }

    pub fn assetById(self: Project, asset_id: media.AssetId) ?media.MediaAsset {
        for (self.assets.items) |asset| {
            if (asset.id.value == asset_id.value) return asset;
        }
        return null;
    }
};

const SerializedProject = struct {
    schema_version: u32,
    project_id: []const u8,
    assets: []SerializedAsset = &.{},
    timeline: SerializedTimeline = .{},
};

const SerializedTimeline = struct {
    tracks: []std.json.Value = &.{},
    clips: []SerializedClip = &.{},
};

const SerializedAsset = struct {
    id: u64,
    display_name: []const u8,
    source_path: []const u8,
    kind: media.MediaKind,
    status: media.MediaStatus,
    duration_seconds: ?f64 = null,
    dimensions: ?media.Dimensions = null,
    import_order: u64 = 0,
};

const SerializedClip = struct {
    id: u64,
    asset_id: u64,
    media_kind: media.MediaKind = .unknown,
    track_id: u64,
    track_index: usize,
    timeline_start: f64,
    source_in: f64 = 0.0,
    duration: f64,
    opacity: f32 = 1.0,
    blend_mode: timeline_model.BlendMode = .normal,
    opacity_keyframes: []SerializedKeyframe = &.{},
};

const SerializedKeyframe = struct {
    time: f64,
    value: f32,
    interpolation: timeline_model.KeyframeInterpolation = .linear,
};

pub fn pathExists(io: std.Io, source_path: []const u8) bool {
    std.Io.Dir.cwd().access(io, source_path, .{ .read = true }) catch return false;
    return true;
}

fn revalidatedStatus(
    io: std.Io,
    source_path: []const u8,
    kind: media.MediaKind,
    persisted_status: media.MediaStatus,
) media.MediaStatus {
    if (kind == .unknown or persisted_status == .unsupported) return .unsupported;
    if (pathExists(io, source_path)) return .available;
    return .missing;
}

fn ownedOpacityKeyframesFromSerialized(
    allocator: std.mem.Allocator,
    serialized: []const SerializedKeyframe,
    clip_duration: f64,
) ![]timeline_model.ScalarKeyframe {
    if (serialized.len == 0) return &.{};

    const keyframes = try allocator.alloc(timeline_model.ScalarKeyframe, serialized.len);
    errdefer allocator.free(keyframes);

    var previous_time: ?f64 = null;
    for (serialized, 0..) |keyframe, index| {
        try validateSerializedKeyframe(keyframe, clip_duration, previous_time);
        keyframes[index] = .{
            .time = keyframe.time,
            .value = keyframe.value,
            .interpolation = keyframe.interpolation,
        };
        previous_time = keyframe.time;
    }

    return keyframes;
}

fn validateSerializedKeyframe(
    keyframe: SerializedKeyframe,
    clip_duration: f64,
    previous_time: ?f64,
) timeline_model.ClipEditError!void {
    if (!std.math.isFinite(keyframe.time) or keyframe.time < 0.0 or keyframe.time > clip_duration) {
        return timeline_model.ClipEditError.InvalidKeyframe;
    }
    if (!std.math.isFinite(keyframe.value) or keyframe.value < 0.0 or keyframe.value > 1.0) {
        return timeline_model.ClipEditError.InvalidKeyframe;
    }
    if (previous_time) |time| {
        if (keyframe.time <= time) return timeline_model.ClipEditError.InvalidKeyframe;
    }
}

fn writeTestFile(dir: std.Io.Dir, path: []const u8, data: []const u8) !void {
    try dir.writeFile(std.testing.io, .{ .sub_path = path, .data = data });
}

fn tmpProjectPath(allocator: std.mem.Allocator, tmp: std.testing.TmpDir, path: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, path });
}

fn importSingleFixture(
    project: *Project,
    tmp: std.testing.TmpDir,
    path: []const u8,
) !struct { result: media.ImportResult, source_path: []u8 } {
    try writeTestFile(tmp.dir, path, "fixture");
    const source_path = try tmpProjectPath(project.allocator, tmp, path);
    errdefer project.allocator.free(source_path);
    return .{ .result = try project.importPath(std.testing.io, source_path), .source_path = source_path };
}

test "empty project initializes and cleans up" {
    var project = try Project.init(std.testing.allocator, "project-empty");
    defer project.deinit();

    try std.testing.expectEqualStrings("project-empty", project.id);
    try std.testing.expectEqual(@as(usize, 0), project.assets.items.len);
    try std.testing.expectEqual(@as(usize, 4), project.timeline.tracks().len);
    try std.testing.expectEqual(@as(usize, 0), project.clipCount());
    try std.testing.expectEqual(@as(u64, 1), project.next_asset_id);
}

test "import handles available assets duplicates unknowns and spaces" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = try Project.init(std.testing.allocator, "project-imports");
    defer project.deinit();

    const imported = try importSingleFixture(&project, tmp, "clip with spaces.mp4");
    defer std.testing.allocator.free(imported.source_path);
    try std.testing.expectEqual(media.ImportOutcome.imported, imported.result.outcome());
    try std.testing.expectEqual(media.MediaStatus.available, imported.result.status());
    try std.testing.expectEqual(@as(usize, 1), project.assets.items.len);
    try std.testing.expectEqualStrings("clip with spaces.mp4", project.assets.items[0].display_name);

    const duplicate = try project.importPath(std.testing.io, imported.source_path);
    try std.testing.expectEqual(media.ImportOutcome.duplicate, duplicate.outcome());
    try std.testing.expectEqual(@as(usize, 1), project.assets.items.len);
    try std.testing.expectEqual(@as(?media.AssetId, media.AssetId.init(1)), duplicate.assetId());

    const missing = try project.importPath(std.testing.io, "offline/missing.wav");
    try std.testing.expectEqual(media.ImportOutcome.imported, missing.outcome());
    try std.testing.expectEqual(media.MediaStatus.missing, missing.status());
    try std.testing.expectEqual(@as(usize, 2), project.assets.items.len);
    try std.testing.expectError(
        timeline_model.ClipCreationError.MissingAsset,
        project.addAssetToTimeline(1, .{}),
    );

    const unsupported = try project.importPath(std.testing.io, "notes.txt");
    try std.testing.expectEqual(media.ImportOutcome.unsupported, unsupported.outcome());
    try std.testing.expectEqual(@as(usize, 2), project.assets.items.len);
    try std.testing.expectError(ProjectError.AssetIndexOutOfBounds, project.addAssetToTimeline(99, .{}));
}

test "multi import loop preserves deterministic order" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = try Project.init(std.testing.allocator, "project-loop");
    defer project.deinit();

    const paths = [_][]const u8{ "a.mp4", "b.wav", "c.srt" };
    for (paths) |path| {
        const imported = try importSingleFixture(&project, tmp, path);
        defer std.testing.allocator.free(imported.source_path);
        try std.testing.expectEqual(media.ImportOutcome.imported, imported.result.outcome());
    }

    try std.testing.expectEqual(@as(usize, 3), project.assets.items.len);
    for (project.assets.items, 0..) |asset, index| {
        try std.testing.expectEqual(@as(u64, @intCast(index + 1)), asset.id.value);
        try std.testing.expectEqual(index, asset.import_order);
    }
}

test "project JSON round trip preserves asset fields" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = try Project.init(std.testing.allocator, "project-round-trip");
    defer project.deinit();

    const imported = try importSingleFixture(&project, tmp, "round trip.webm");
    defer std.testing.allocator.free(imported.source_path);
    project.assets.items[0].duration_seconds = 12.5;
    project.assets.items[0].dimensions = .{ .width = 1920, .height = 1080 };
    const clip = try project.addAssetToTimeline(0, .{ .timeline_start = 2.0, .source_in = 0.5 });
    try std.testing.expectEqual(@as(u64, 1), clip.id.value);

    const json = try project.toOwnedJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    var loaded = try Project.loadFromSlice(std.testing.allocator, std.testing.io, json);
    defer loaded.deinit();

    try std.testing.expectEqualStrings(project.id, loaded.id);
    try std.testing.expectEqual(@as(usize, 1), loaded.assets.items.len);
    const asset = loaded.assets.items[0];
    try std.testing.expectEqual(project.assets.items[0].id, asset.id);
    try std.testing.expectEqualStrings(project.assets.items[0].display_name, asset.display_name);
    try std.testing.expectEqualStrings(project.assets.items[0].source_path, asset.source_path);
    try std.testing.expectEqual(project.assets.items[0].kind, asset.kind);
    try std.testing.expectEqual(media.MediaStatus.available, asset.status);
    try std.testing.expectEqual(@as(?f64, 12.5), asset.duration_seconds);
    try std.testing.expectEqual(@as(?media.Dimensions, .{ .width = 1920, .height = 1080 }), asset.dimensions);
    try std.testing.expectEqual(@as(u64, 0), asset.import_order);
    try std.testing.expectEqual(@as(usize, 1), loaded.clipCount());
    const summary = loaded.clipSummary(0).?;
    try std.testing.expectEqual(@as(u64, 1), summary.clip_id.value);
    try std.testing.expectEqual(asset.id, summary.asset_id);
    try std.testing.expectEqualStrings("round trip.webm", summary.label);
    try std.testing.expectEqual(@as(f64, 2.0), summary.timeline_start);
    try std.testing.expectEqual(@as(f64, 0.5), summary.source_in);
    try std.testing.expectEqual(@as(f64, 12.5), summary.duration);
    try std.testing.expectEqual(@as(?timeline_model.ClipSummary, null), loaded.clipSummary(1));
}

test "project editing methods wrap timeline operations and keep assets stable" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = try Project.init(std.testing.allocator, "project-edits");
    defer project.deinit();

    const imported = try importSingleFixture(&project, tmp, "edit.mp4");
    defer std.testing.allocator.free(imported.source_path);
    _ = try project.addAssetToTimeline(0, .{ .timeline_start = 0.0, .duration_seconds = 5.0 });
    try project.setClipOpacityKeyframe(0, 0.0, 0.0);
    try project.setClipOpacityKeyframe(0, 5.0, 1.0);

    const right = try project.splitClip(0, 2.0);
    try std.testing.expectEqual(@as(u64, 2), right.id.value);
    _ = try project.trimClip(1, .{ .timeline_start = 2.0, .source_in = 2.0, .duration = 2.0 });
    _ = try project.moveClip(1, .{ .track_index = 0, .timeline_start = 3.0 });

    try std.testing.expectEqual(@as(usize, 1), project.assets.items.len);
    try std.testing.expectEqual(@as(u64, 1), project.assets.items[0].id.value);
    try std.testing.expectEqualStrings(imported.source_path, project.assets.items[0].source_path);
    try std.testing.expectEqual(@as(usize, 2), project.clipCount());

    const first = project.clipSummary(0).?;
    const second = project.clipSummary(1).?;
    try std.testing.expectEqual(@as(u64, 1), first.clip_id.value);
    try std.testing.expectEqual(@as(f64, 0.0), first.timeline_start);
    try std.testing.expectEqual(@as(f64, 2.0), first.duration);
    try std.testing.expectEqual(@as(u64, 2), second.clip_id.value);
    try std.testing.expectEqual(@as(f64, 3.0), second.timeline_start);
    try std.testing.expectEqual(@as(f64, 2.0), second.source_in);
    try std.testing.expectEqual(@as(f64, 2.0), second.duration);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), try project.evaluateClipOpacity(0, 1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), try project.evaluateClipOpacity(1, 1.0), 0.0001);
}

test "project JSON round trip preserves edited clips and opacity keyframes" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = try Project.init(std.testing.allocator, "project-edit-round-trip");
    defer project.deinit();

    const imported = try importSingleFixture(&project, tmp, "keyframed.webm");
    defer std.testing.allocator.free(imported.source_path);
    _ = try project.addAssetToTimeline(0, .{ .timeline_start = 0.0, .duration_seconds = 5.0 });
    try project.setClipOpacityKeyframe(0, 0.0, 0.0);
    try project.setClipOpacityKeyframe(0, 5.0, 1.0);
    _ = try project.splitClip(0, 2.0);
    _ = try project.trimClip(1, .{ .timeline_start = 2.0, .source_in = 2.0, .duration = 2.0 });
    _ = try project.moveClip(1, .{ .track_index = 0, .timeline_start = 4.0 });

    const json = try project.toOwnedJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"opacity_keyframes\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"media_kind\"") != null);

    var loaded = try Project.loadFromSlice(std.testing.allocator, std.testing.io, json);
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 2), loaded.clipCount());
    try std.testing.expectEqual(@as(u64, 3), loaded.timeline.next_clip_id);
    try std.testing.expectEqual(media.MediaKind.video, loaded.timeline.clips.items[0].media_kind);
    try std.testing.expectEqual(media.MediaKind.video, loaded.timeline.clips.items[1].media_kind);
    try std.testing.expectEqual(@as(usize, 2), loaded.timeline.clips.items[0].opacity_keyframes.len);
    try std.testing.expectEqual(@as(usize, 2), loaded.timeline.clips.items[1].opacity_keyframes.len);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), try loaded.evaluateClipOpacity(0, 1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), try loaded.evaluateClipOpacity(1, 1.0), 0.0001);

    const second = loaded.clipSummary(1).?;
    try std.testing.expectEqual(@as(f64, 4.0), second.timeline_start);
    try std.testing.expectEqual(@as(f64, 2.0), second.source_in);
    try std.testing.expectEqual(@as(f64, 2.0), second.duration);
}

test "old schema clips without keyframes load with defaults" {
    const json =
        \\{
        \\  "schema_version": 1,
        \\  "project_id": "old-schema",
        \\  "assets": [
        \\    {
        \\      "id": 4,
        \\      "display_name": "legacy.mp4",
        \\      "source_path": "legacy.mp4",
        \\      "kind": "video",
        \\      "status": "available",
        \\      "duration_seconds": 4.0,
        \\      "dimensions": null,
        \\      "import_order": 0
        \\    }
        \\  ],
        \\  "timeline": {
        \\    "tracks": [],
        \\    "clips": [
        \\      {
        \\        "id": 7,
        \\        "asset_id": 4,
        \\        "track_id": 1,
        \\        "track_index": 0,
        \\        "timeline_start": 1.0,
        \\        "source_in": 0.5,
        \\        "duration": 3.0,
        \\        "opacity": 1.0,
        \\        "blend_mode": "normal"
        \\      }
        \\    ]
        \\  }
        \\}
    ;

    var loaded = try Project.loadFromSlice(std.testing.allocator, std.testing.io, json);
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.clipCount());
    try std.testing.expectEqual(@as(u64, 8), loaded.timeline.next_clip_id);
    try std.testing.expectEqual(media.MediaKind.video, loaded.timeline.clips.items[0].media_kind);
    try std.testing.expectEqual(@as(usize, 0), loaded.timeline.clips.items[0].opacity_keyframes.len);
    try std.testing.expectEqual(@as(f32, 1.0), try loaded.evaluateClipOpacity(0, 1.0));
}

test "invalid project edits leave assets clips and keyframes unchanged" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = try Project.init(std.testing.allocator, "project-invalid-edits");
    defer project.deinit();

    const imported = try importSingleFixture(&project, tmp, "dialog.wav");
    defer std.testing.allocator.free(imported.source_path);
    _ = try project.addAssetToTimeline(0, .{ .timeline_start = 0.0, .duration_seconds = 3.0 });
    try project.setClipOpacityKeyframe(0, 0.5, 0.5);

    const before_asset_count = project.assets.items.len;
    const before_clip = project.timeline.clips.items[0];
    const before_keyframe = before_clip.opacity_keyframes[0];

    try std.testing.expectError(
        timeline_model.ClipEditError.IncompatibleTrack,
        project.moveClip(0, .{ .track_index = 0, .timeline_start = 1.0 }),
    );
    try std.testing.expectError(
        timeline_model.ClipEditError.InvalidKeyframe,
        project.setClipOpacityKeyframe(0, 4.0, 0.25),
    );
    try std.testing.expectError(
        timeline_model.ClipCreationError.InvalidTime,
        project.trimClip(0, .{ .timeline_start = 0.0, .source_in = 0.0, .duration = 0.0 }),
    );

    try std.testing.expectEqual(before_asset_count, project.assets.items.len);
    try std.testing.expectEqual(before_clip.id, project.timeline.clips.items[0].id);
    try std.testing.expectEqual(before_clip.track_id, project.timeline.clips.items[0].track_id);
    try std.testing.expectEqual(before_clip.track_index, project.timeline.clips.items[0].track_index);
    try std.testing.expectEqual(before_clip.timeline_start, project.timeline.clips.items[0].timeline_start);
    try std.testing.expectEqual(before_clip.source_in, project.timeline.clips.items[0].source_in);
    try std.testing.expectEqual(before_clip.duration, project.timeline.clips.items[0].duration);
    try std.testing.expectEqual(@as(usize, 1), project.timeline.clips.items[0].opacity_keyframes.len);
    try std.testing.expectEqual(before_keyframe.time, project.timeline.clips.items[0].opacity_keyframes[0].time);
    try std.testing.expectEqual(before_keyframe.value, project.timeline.clips.items[0].opacity_keyframes[0].value);
}

test "load marks missing persisted sources offline" {
    const json =
        \\{
        \\  "schema_version": 1,
        \\  "project_id": "missing-load",
        \\  "assets": [
        \\    {
        \\      "id": 9,
        \\      "display_name": "gone.mov",
        \\      "source_path": "gone.mov",
        \\      "kind": "video",
        \\      "status": "available",
        \\      "duration_seconds": null,
        \\      "dimensions": null,
        \\      "import_order": 0
        \\    }
        \\  ],
        \\  "timeline": { "tracks": [], "clips": [] }
        \\}
    ;

    var loaded = try Project.loadFromSlice(std.testing.allocator, std.testing.io, json);
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.assets.items.len);
    try std.testing.expectEqual(media.MediaStatus.missing, loaded.assets.items[0].status);
    try std.testing.expectEqual(@as(u64, 10), loaded.next_asset_id);
}

test "load rejects unsupported schema and malformed JSON clearly" {
    try std.testing.expectError(
        ProjectError.UnsupportedSchema,
        Project.loadFromSlice(std.testing.allocator, std.testing.io,
            \\{"schema_version":99,"project_id":"future","assets":[],"timeline":{"tracks":[],"clips":[]}}
        ),
    );

    try std.testing.expectError(
        error.SyntaxError,
        Project.loadFromSlice(std.testing.allocator, std.testing.io, "{not-json"),
    );
}
