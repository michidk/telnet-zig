const std = @import("std");
const io = std.io;
const net = std.net;
const print = std.debug.print;
const client = @import("client.zig");
const opts = @import("opts.zig");
const clap = @import("clap");

pub const std_options = struct {
    pub const log_level = .debug; // Set this to `.warn` to disable all debug info
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

        // Commenct to the server
        std.log.info("Connecting to {?s}:{?d}\n", .{ args.uri.host, args.uri.port });
        const stream = try net.tcpConnectToHost(alloc, args.uri.host.?, args.uri.port.?);
        defer stream.close();

        var tnClient = client.TelnetClient.init(stream);

        // Start the input thread
        std.log.info("Press CTL-C to exit.", .{});
        const handle = try std.Thread.spawn(.{}, readInput, .{&tnClient});
        handle.detach();

        while (true) {
            try tnClient.read();
        }
    }
}

fn readInput(tnClient: *client.TelnetClient) !void {
    // Read from stdin and write to the telnet client

    // Sadly, this does not work, since data is only read once enter is pressed
    // Normaly, telnet would send a key press as soon as it is pressed
    // But for this to work, we would need to use a terminal library
    // Also our enter would have to be translated from \n to \r\n

    const stdin = std.io.getStdIn().reader();
    while (true) {
        var buf: [64]u8 = undefined;
        const len = try stdin.read(&buf);
        if (len > 0) {
            try tnClient.write(buf[0..len]);
        }
    }
}
