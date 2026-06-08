const std = @import("std");
const Io = std.Io;
const pontificate = @import("pontificate");
const project = pontificate.project;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();
    if (args.next()) |command| {
        if (std.mem.eql(u8, command, "inspect")) {
            const path = args.next() orelse return error.MissingProjectPath;
            try inspectProject(init, path);
            return;
        }
        if (std.mem.eql(u8, command, "import-save")) {
            const project_id = args.next() orelse return error.MissingProjectId;
            const output_path = args.next() orelse return error.MissingProjectPath;
            try importAndSave(init, project_id, output_path, &args);
            return;
        }
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    const stats = pontificate.defaultProjectStats();
    const opacity_midpoint = pontificate.evaluateLinear(0.0, 1.0, 0.0, 1.2, 0.6);

    try stdout.print("Pontificate core {s}\n", .{pontificate.version});
    try stdout.print("{s}\n", .{pontificate.default_project_summary});
    try stdout.print(
        "tracks={d} clips={d} subtitle_cues={d} opacity_at_0.6s={d:.2}\n",
        .{ stats.tracks, stats.clips, stats.subtitle_cues, opacity_midpoint },
    );
    try stdout.print("timeline_edit_ops=split,trim,move keyframes=opacity\n", .{});
    try stdout.flush();
}

fn inspectProject(init: std.process.Init, path: []const u8) !void {
    var loaded = project.Project.loadFromFile(init.gpa, init.io, path) catch |err| {
        var stderr_buffer: [512]u8 = undefined;
        var stderr_writer = Io.File.stderr().writer(init.io, &stderr_buffer);
        const stderr = &stderr_writer.interface;
        try stderr.print("failed to load project '{s}': {s}\n", .{ path, @errorName(err) });
        try stderr.flush();
        return err;
    };
    defer loaded.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "project={s} schema={d} assets={d} clips={d}\n",
        .{ loaded.id, project.schema_version, loaded.assets.items.len, loaded.clipCount() },
    );
    for (loaded.assets.items) |asset| {
        try stdout.print(
            "asset id={d} kind={s} status={s} name=\"{s}\" path=\"{s}\"\n",
            .{
                asset.id.value,
                @tagName(asset.kind),
                @tagName(asset.status),
                asset.display_name,
                asset.source_path,
            },
        );
    }
    var clip_index: usize = 0;
    while (clip_index < loaded.clipCount()) : (clip_index += 1) {
        const summary = loaded.clipSummary(clip_index) orelse continue;
        const eval_time = if (summary.duration < 0.5) summary.duration else 0.5;
        const opacity = try loaded.evaluateClipOpacity(clip_index, eval_time);
        try stdout.print(
            "clip index={d} id={d} asset={d} track={d} start={d:.2} source_in={d:.2} duration={d:.2} opacity={d:.2} opacity_at_{d:.2}s={d:.2} blend={s}\n",
            .{
                clip_index,
                summary.clip_id.value,
                summary.asset_id.value,
                summary.track_index,
                summary.timeline_start,
                summary.source_in,
                summary.duration,
                summary.opacity,
                eval_time,
                opacity,
                @tagName(summary.blend_mode),
            },
        );
    }
    try stdout.flush();
}

fn importAndSave(
    init: std.process.Init,
    project_id: []const u8,
    output_path: []const u8,
    args: *std.process.Args.Iterator,
) !void {
    var created = try project.Project.init(init.gpa, project_id);
    defer created.deinit();

    var import_count: usize = 0;
    while (args.next()) |source_path| {
        const result = try created.importPath(init.io, source_path);
        if (result.outcome() == .imported) import_count += 1;
    }

    try created.saveToFile(init.io, output_path);

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "saved project={s} assets={d} imported={d} path={s}\n",
        .{ created.id, created.assets.items.len, import_count, output_path },
    );
    try stdout.flush();
}
