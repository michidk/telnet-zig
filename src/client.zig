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
};

const StateInfo = union(State) {
    normal: void,
    iac: void,
    negotiating: telnet.Command,
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

    pub fn read(self: *TelnetClient) anyerror!void {
        const byte = try self.reader.readByte();

        switch (self.state) {
            .normal => {
                if (byte == telnet.IAC_BYTE) {
                    print("Server ({s}): IAC ", .{@tagName(self.state)});
                    self.state = .iac;
                } else {
                    print("{c}", .{byte});
                }
            },
            .iac => {
                var cmd: telnet.Command = @enumFromInt(byte);
                switch (cmd) {
                    .se => {
                        print("SE \n", .{});
                        self.state = .normal;
                    },
                    .nop => {
                        print("NOP \n", .{});
                        self.state = .normal;
                    },
                    .dm => {
                        print("DM \n", .{});
                        self.state = .normal;
                    },
                    .brk => {
                        print("BRK \n", .{});
                        self.state = .normal;
                    },
                    .ip => {
                        print("IP \n", .{});
                        self.state = .normal;
                    },
                    .ao => {
                        print("AO \n", .{});
                        self.state = .normal;
                    },
                    .ayt => {
                        print("AYT \n", .{});
                        self.state = .normal;
                    },
                    .ec => {
                        print("EC \n", .{});
                        self.state = .normal;
                    },
                    .el => {
                        print("EL \n", .{});
                        self.state = .normal;
                    },
                    .ga => {
                        print("GA \n", .{});
                        self.state = .normal;
                    },
                    .sb => {
                        print("SB \n", .{});
                        self.state = .normal;
                    },
                    .will => {
                        print("WILL ", .{});
                        self.state = StateInfo{ .negotiating = .will };
                    },
                    .wont => {
                        print("WONT ", .{});
                        self.state = StateInfo{ .negotiating = .wont };
                    },
                    .do => {
                        print("DO ", .{});
                        self.state = StateInfo{ .negotiating = .do };
                    },
                    .dont => {
                        print("DONT ", .{});
                        self.state = StateInfo{ .negotiating = .dont };
                    },
                }
            },
            .negotiating => |command| {
                const opt: telnet.Option = @enumFromInt(byte);
                print("{s}\n", .{@tagName(opt)});

                switch (opt) {
                    .echo => {
                        switch (command) {
                            .will => {
                                try self.send(.do, .echo);
                            },
                            .wont => {
                                try self.send(.dont, .echo);
                            },
                            else => {},
                        }
                    },
                    .suppressGoAhead => {
                        switch (command) {
                            .will => {
                                try self.send(.do, .suppressGoAhead);
                            },
                            .wont => {
                                try self.send(.dont, .suppressGoAhead);
                            },
                            else => {},
                        }
                    },
                    .negotiateAboutWindowSize => {
                        // https://datatracker.ietf.org/doc/html/rfc1073
                        switch (command) {
                            .do => {
                                try self.send(.will, .negotiateAboutWindowSize);
                                try self.writer.writeAll(&[_]u8{ telnet.IAC_BYTE, telnet.SB_BYTE, @intFromEnum(Option.negotiateAboutWindowSize), 0, 80, 0, 24, telnet.IAC_BYTE, telnet.SE_BYTE });
                            },
                            .dont => {
                                try self.send(.wont, .negotiateAboutWindowSize);
                            },
                            else => {},
                        }
                    },
                    .terminalType => {
                        // https://datatracker.ietf.org/doc/html/rfc1091
                        switch (command) {
                            .do => {
                                try self.send(.wont, .terminalType);
                                try self.writer.writeAll(&[_]u8{ telnet.IAC_BYTE, telnet.SB_BYTE, @intFromEnum(Option.terminalType), 0, 0, 0, 0, 0, 0, 0, 0, 0, telnet.IAC_BYTE, telnet.SE_BYTE });
                            },
                            .dont => {
                                try self.send(.wont, .terminalType);
                            },
                            else => {},
                        }
                    },
                    else => {},
                }

                self.state = .normal;
            },
        }
    }

    fn send(self: *TelnetClient, command: Command, option: Option) anyerror!void {
        print("Client ({s}): IAC {s} {s}\n", .{ @tagName(self.state), @tagName(command), @tagName(option) });
        try self.writer.writeAll(&telnet.instruction(command, option));
    }
};
