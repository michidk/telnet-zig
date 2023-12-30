const std = @import("std");
const io = std.io;
const net = std.net;
const fs = std.fs;
const os = std.os;
const print = std.debug.print;
const telnet = @import("telnet.zig");
const Command = telnet.Command;
const Option = telnet.Option;

const State = enum {
    normal,
    iac,
    negotiating,
    subnegotiating,
};

const StateInfo = union(State) {
    normal: void,
    iac: void,
    negotiating: telnet.Command,
    subnegotiating: telnet.Option,
};

pub const TelnetClient = struct {
    stream: net.Stream,
    reader: net.Stream.Reader,
    writer: net.Stream.Writer,
    state: StateInfo,

    pub fn init(stream: net.Stream) TelnetClient {
        return TelnetClient{
            .stream = stream,
            .reader = stream.reader(),
            .writer = stream.writer(),
            .state = .normal,
        };
    }

    pub fn write(self: *TelnetClient, data: []u8) anyerror!void {
        std.log.debug("Writing {d} bytes", .{data.len});

        // TODO: escape IAC bytes
        try self.writer.writeAll(data);
    }

    pub fn read(self: *TelnetClient) anyerror!void {
        const byte = try self.reader.readByte();

        switch (self.state) {

            // Normal state: print characters and wait for IAC byte
            .normal => {
                if (byte == telnet.IAC_BYTE) {
                    self.state = .iac;
                } else {
                    print("{c}", .{byte});
                }
            },

            // Command state: determine command and set negotiating state
            .iac => {
                var cmd: telnet.Command = @enumFromInt(byte);
                switch (cmd) {
                    .nop => {
                        // Do nothing
                        std.log.debug("Recieved NOP", .{});
                        self.state = .normal;
                    },
                    .iac => {
                        // Escaped IAC byte
                        print("{c}", .{telnet.IAC_BYTE});
                        self.state = .normal;
                    },
                    .will, .wont, .do, .dont, .sb => {
                        self.state = StateInfo{ .negotiating = cmd };
                    },
                    .se => {
                        // Subnegotiation end
                        self.state = .normal;
                    },
                    else => {
                        std.log.warn("Unhandled command: {s} (state: {s})", .{ @tagName(cmd), @tagName(self.state) });
                        self.state = .normal;
                    },
                }
            },

            // Negotiating state: determine option and send response
            .negotiating => |command| {
                const option: telnet.Option = @enumFromInt(byte);
                std.log.debug("S: {s} {s}", .{ @tagName(command), @tagName(option) });

                switch (option) {
                    .echo => {
                        // https://datatracker.ietf.org/doc/html/rfc857
                        switch (command) {
                            .will => {
                                std.log.debug("Server wants to echo, we allow him", .{});
                                try self.send(.do, .echo);
                            },
                            .wont => {
                                std.log.debug("Server does not want to echo, we are fine with that", .{});
                                try self.send(.dont, .echo);
                            },
                            .do => {
                                std.log.debug("Server asks us to echo, we decline", .{});
                                try self.send(.wont, .echo);
                            },
                            .dont => {
                                std.log.debug("Server asks us not to echo, we won't", .{});
                                try self.send(.wont, .echo);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                    .suppressGoAhead => {
                        // https://datatracker.ietf.org/doc/html/rfc858
                        switch (command) {
                            .will => {
                                std.log.debug("Server wants to suppress go ahead, we allow him", .{});
                                try self.send(.do, .suppressGoAhead);
                            },
                            .wont => {
                                std.log.warn("Server refused to suppress go ahead", .{});
                                try self.send(.do, .suppressGoAhead);
                            },
                            .do => {
                                std.log.debug("Server asks us to suppress go ahead, we accept", .{});
                                try self.send(.will, .suppressGoAhead);
                            },
                            .dont => {
                                std.log.warn("Server asks us not to suppress go ahead, we won't", .{});
                                try self.send(.wont, .suppressGoAhead);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                    .negotiateAboutWindowSize => {
                        // https://datatracker.ietf.org/doc/html/rfc1073
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants to negotiate about window size, we send the info", .{});
                                try self.send(.will, .negotiateAboutWindowSize);

                                // TODO: get the correct width and height from the terminal
                                const windowSizeData = &[_]u8{
                                    0, 80, // Width
                                    0, 24, // Height
                                };
                                const negotiation = &telnet.subnegotiate(Option.negotiateAboutWindowSize, windowSizeData);
                                try self.writer.writeAll(negotiation);
                            },
                            .dont => {
                                std.log.debug("Server does not want to negotiate about window size, we accept", .{});
                                try self.send(.wont, .negotiateAboutWindowSize);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                    .terminalType => {
                        // https://datatracker.ietf.org/doc/html/rfc1091
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants to ask us for our terminal type, we agree", .{});
                                try self.send(.will, .terminalType);

                                self.state = .normal;
                            },
                            .dont => {
                                std.log.debug("Server does not want to know our terminal type", .{});
                                try self.send(.wont, .terminalType);

                                self.state = .normal;
                            },
                            .sb => {
                                std.log.debug("Server wants to know our terminal type...", .{});

                                self.state = StateInfo{
                                    .subnegotiating = Option.terminalType,
                                };
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                    },
                    .transmitBinary => {
                        // https://datatracker.ietf.org/doc/html/rfc856
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants to transmit binary, we agree", .{});
                                try self.send(.will, .transmitBinary);
                            },
                            .dont => {
                                std.log.debug("Server does not want to transmit binary, we agree", .{});
                                try self.send(.wont, .transmitBinary);
                            },
                            .will => {
                                std.log.debug("Server wants us to transmit binary, we agree", .{});
                                try self.send(.do, .transmitBinary);
                            },
                            .wont => {
                                std.log.debug("Server does not want us to transmit binary, we agree", .{});
                                try self.send(.dont, .transmitBinary);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                    },
                    else => {
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants us to perform subcommand `{s}`, we refuse", .{@tagName(option)});
                                try self.send(.wont, option);
                            },
                            .dont => {
                                std.log.debug("Server does not want us to perform subcommand `{s}`, we refuse", .{@tagName(option)});
                            },
                            .will, .wont => {
                                std.log.warn("Server wants to negotiate option `{s}`", .{@tagName(option)});
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                }
            },

            // Subnegotiating state: determine option and read until IAC SE
            .subnegotiating => |option| {
                std.log.debug("Subnegotiating option `{s}`", .{@tagName(option)});
                switch (option) {
                    .terminalType => {
                        if (byte == telnet.SEND_BYTE) {
                            std.log.debug("Send terminal type", .{});
                            const terminalTypeData: []const u8 = &[_]u8{
                                telnet.IS_BYTE, // Is
                                'X', 'T', 'E', 'R', 'M', '-', '2', '5', '6', 'C', 'O', 'L', 'O', 'R', // Terminal type (`XTERM-256COLOR` is what the inetutils implementation sends)
                            };
                            const negotiation: []const u8 = &telnet.subnegotiate(Option.terminalType, terminalTypeData);
                            try self.writer.writeAll(negotiation);

                            self.state = .normal;
                        } else {
                            std.log.warn("Unsupported data byte {d} during subnegotiation option `{c}` (state: {s}),", .{ byte, @tagName(option), @tagName(self.state) });
                            self.state = .normal;
                        }
                    },
                    else => {
                        std.log.warn("Unsupported subnegotiation option `{s}` (state: {s})", .{ @tagName(option), @tagName(self.state) });
                        self.state = .normal;
                    },
                }
            },
        }
    }

    fn send(self: *TelnetClient, command: Command, option: Option) anyerror!void {
        std.log.debug("C: {s} {s}", .{ @tagName(command), @tagName(option) });
        try self.writer.writeAll(&telnet.instruction(command, option));
    }
};
