const std = @import("std");
const Io = std.Io;
const pontificate = @import("pontificate");

pub fn main(init: std.process.Init) !void {
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
    try stdout.flush();
}
