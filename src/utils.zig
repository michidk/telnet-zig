const std = @import("std");

/// Removes the specified prefix from the given string if it starts with it.
pub fn removePrefix(input: []const u8, prefix: []const u8) []const u8 {
    if (std.mem.startsWith(u8, input, prefix)) {
        return input[prefix.len..];
    }
    return input;
}
