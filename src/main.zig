const std = @import("std");
const io = std.io;
const net = std.net;
const print = std.debug.print;
const client = @import("client.zig");
const opts = @import("opts.zig");
const clap = @import("clap");

const Errors = error{
    MissingArgument,
    InvalidUri,
};

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var alloc = gpa.allocator();

    // Parse command line arguments
    const parsedArgs = try opts.parse(alloc);
    if (parsedArgs) |args| {
        defer args.deinit();
        std.log.info("Connecting to {?s}:{?d}\n", .{ args.uri.host, args.uri.port });
        const stream = try net.tcpConnectToHost(alloc, args.uri.host.?, args.uri.port.?);
        defer stream.close();

        var tnClient = client.TelnetClient.init(stream);
        while (true) {
            try tnClient.read();
        }
    }
}
