const std = @import("std");
const io = std.io;
const net = std.net;
const print = std.debug.print;
const client = @import("client.zig");
const clap = @import("clap");
const utils = @import("utils.zig");

const DEFAULT_PORT: u16 = 23;

const Errors = error{
    HostMissing,
    InvalidPort,
};

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var alloc = gpa.allocator();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help.
        \\<str>                     The host to connect to.
        \\<str>                     The port to connect to.
        \\
    );

    // Clap diagnostics are used to report errors to the user.
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});
    } else {
        if (res.positionals.len < 1) {
            std.log.err("Missing host. Use -h to print the help.\n", .{});
            return error.HostMissing;
        }

        const port = port: {
            if (res.positionals.len < 2) {
                std.log.warn("Missing port, using default port {d}.\n", .{DEFAULT_PORT});
                break :port DEFAULT_PORT;
            } else {
                break :port std.fmt.parseInt(u16, res.positionals[1], 10) catch {
                    std.log.err("Invalid port: {s}\n", .{res.positionals[1]});
                    return error.InvalidPort;
                };
            }
        };

        const host: []const u8 = utils.removePrefix(res.positionals[0], "telnet://");

        std.log.info("Connecting to {s}:{d}\n", .{ host, port });
        const stream = try net.tcpConnectToHost(alloc, host, port);
        defer stream.close();

        var tnClient = client.TelnetClient.init(stream);
        while (true) {
            try tnClient.read();
        }
    }
}
