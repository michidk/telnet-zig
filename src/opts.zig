const std = @import("std");
const clap = @import("clap");
const utils = @import("utils.zig");
const telnet = @import("telnet.zig");
const io = std.io;

const OptErrors = error{
    MissingArgument,
    InvalidUri,
};

pub const Opts = struct {
    alloc: std.mem.Allocator,
    uriStr: []const u8,
    uri: std.Uri,

    pub fn init(alloc: std.mem.Allocator, uriStrInp: []const u8) !Opts {
        const uriStrWithoutPrefix: []const u8 = utils.removePrefix(uriStrInp, "telnet://");
        const uriStr: []const u8 = try std.fmt.allocPrint(alloc, "telnet://{s}", .{uriStrWithoutPrefix});

        var uri = std.Uri.parse(uriStr) catch |err| {
            std.log.err("Invalid telnet URI ({any}): {s}\n", .{ err, uriStrInp });
            alloc.free(uriStr);
            return error.InvalidUri;
        };

        if (uri.host == null) {
            std.log.err("Missing host in telnet URI: {s}\n", .{uriStrInp});
            alloc.free(uriStr);
            return error.InvalidUri;
        }

        // Handle default port
        if (uri.port == null) {
            std.log.warn("Missing port, using default port {d}.\n", .{telnet.DEFAULT_PORT});
            uri.port = telnet.DEFAULT_PORT;
        }

        return Opts{ .alloc = alloc, .uri = uri, .uriStr = uriStr };
    }

    pub fn deinit(self: *const Opts) void {
        self.alloc.free(self.uriStr);
    }
};

pub fn parse(alloc: std.mem.Allocator) !?Opts {
    // CLI Parameters
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help.
        \\-u, --usage               Displays a short command usage
        \\<str>                     The telnet URI to connect to.
        \\
    );

    // Clap diagnostics are used to report errors to the user.
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});
        return null;
    } else if (res.args.usage != 0) {
        try clap.usage(std.io.getStdOut().writer(), clap.Help, &params);
        return null;
    } else {
        if (res.positionals.len < 1) {
            std.log.err("Missing telnet URI. Use -h to print the help.\n", .{});
            return error.MissingArgument;
        }

        const uriStrInp: []const u8 = res.positionals[0];
        return try Opts.init(alloc, uriStrInp);
    }
}
