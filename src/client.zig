const std = @import("std");
const io = std.io;
const net = std.net;
const fs = std.fs;
const os = std.os;
const print = std.debug.print;
const telnet = @import("telnet.zig");

const State = enum {
    normal,
    iac,
    negotiating,
};

pub const TelnetClient = struct {
    stream: net.Stream,
    reader: net.Stream.Reader,
    writer: net.Stream.Writer,
    state: State,

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
                    print("IAC ", .{});
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
                        self.state = .negotiating;
                    },
                    .wont => {
                        print("WONT ", .{});
                        self.state = .negotiating;
                    },
                    .do => {
                        print("DO ", .{});
                        self.state = .negotiating;
                    },
                    .dont => {
                        print("DONT ", .{});
                        self.state = .negotiating;
                    },
                }
            },
            .negotiating => {
                var opt: telnet.Option = @enumFromInt(byte);
                print("{s}\n", .{@tagName(opt)});
                self.state = .normal;
            },
        }
    }
};
