const std = @import("std");
const io = std.io;
const net = std.net;
const print = std.debug.print;
const client = @import("client.zig");
const clap = @import("clap");
const utils = @import("utils.zig");

const DEFAULT_PORT: u16 = 23;

const Errors = error{
    MissingArgument,
    InvalidUri,
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
        \\<str>                     The telnet URI to connect to.
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
            // No args are given
            std.log.err("Missing telnet URI. Use -h to print the help.\n", .{});
            return error.MissingArgument;
        }

        // make uri scheme optional
        const uriStr = res.positionals[0];
        const uriStrWithoutPrefix = utils.removePrefix(uriStr, "telnet://");
        const result: []u8 = try std.fmt.allocPrint(alloc, "telnet://{s}", .{uriStrWithoutPrefix});
        defer alloc.free(result);

        print("CONCAT URI: {s}\n", .{result});

        const uri = std.Uri.parse(result) catch |err| {
            std.log.err("Invalid telnet URI ({any}): {s}\n", .{ err, uriStr });
            return error.InvalidUri;
        };

        // Handle default port
        const port = port: {
            if (uri.port != null) {
                break :port uri.port.?;
            } else {
                std.log.warn("Missing port, using default port {d}.\n", .{DEFAULT_PORT});
                break :port DEFAULT_PORT;
            }
        };

        if (uri.host == null) {
            std.log.err("Missing host in telnet URI: {s}\n", .{uriStr});
            return error.InvalidUri;
        }

        std.log.info("Connecting to {?s}:{d}\n", .{ uri.host, port });
        const stream = try net.tcpConnectToHost(alloc, uri.host.?, port);
        defer stream.close();

        var tnClient = client.TelnetClient.init(stream);
        while (true) {
            try tnClient.read();
        }
    }
}
