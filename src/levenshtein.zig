//! UTF-aware Levenshtein distance implementation for Zig
//!
//! This library provides a fast, memory-efficient implementation of the Levenshtein distance algorithm
//! that correctly handles Unicode code points in UTF-8 strings.

const std = @import("std");
const testing = std.testing;
const unicode = std.unicode;

/// Calculates the Levenshtein distance between two UTF-8 strings.
///
/// Returns the minimum number of single-character edits (insertions, deletions, substitutions)
/// required to change one string into another, operating on Unicode code points.
///
/// Parameters:
/// - allocator: Memory allocator for internal working arrays
/// - a: First UTF-8 string
/// - b: Second UTF-8 string
/// - max: Optional maximum distance threshold for early termination
///
/// Returns:
/// - The Levenshtein distance as usize
/// - If max is provided and distance would exceed it, returns max
pub fn levenshtein(allocator: std.mem.Allocator, a: []const u8, b: []const u8, max: ?usize) !usize {
    if (std.mem.eql(u8, a, b)) return 0;
    return levenshteinImpl(allocator, a, b, max);
}

/// UTF-8 iterator for streaming code point access
const Utf8Iterator = struct {
    bytes: []const u8,
    index: usize,

    fn init(bytes: []const u8) @This() {
        return .{ .bytes = bytes, .index = 0 };
    }

    fn next(self: *@This()) ?u21 {
        if (self.index >= self.bytes.len) return null;

        const len = unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch {
            self.index += 1;
            return self.next();
        };

        if (self.index + len > self.bytes.len) return null;

        const codepoint = unicode.utf8Decode(self.bytes[self.index .. self.index + len]) catch {
            self.index += 1;
            return self.next();
        };

        self.index += len;
        return codepoint;
    }
};

/// Core implementation using streaming UTF-8 processing
fn levenshteinImpl(allocator: std.mem.Allocator, a: []const u8, b: []const u8, max: ?usize) !usize {
    // Count code points in each string
    var a_iter = Utf8Iterator.init(a);
    var b_iter = Utf8Iterator.init(b);

    var a_len: usize = 0;
    var b_len: usize = 0;

    while (a_iter.next()) |_| a_len += 1;
    while (b_iter.next()) |_| b_len += 1;

    if (a_len == 0) return b_len;
    if (b_len == 0) return a_len;

    // Ensure a is the shorter string for memory optimization
    var left_bytes = a;
    var right_bytes = b;
    var ll = a_len;
    var rl = b_len;

    if (ll > rl) {
        left_bytes = b;
        right_bytes = a;
        ll = b_len;
        rl = a_len;
    }

    if (max != null and rl - ll >= max.?) return max.?;

    // Allocate working array
    var sfa = std.heap.stackFallback(4096, allocator);
    const alloc = sfa.get();
    const array = try alloc.alloc(usize, ll + 1);
    defer alloc.free(array);

    // Initialize first row
    for (0..ll + 1) |i| array[i] = i;

    // Process each character in the longer string
    var right_iter = Utf8Iterator.init(right_bytes);
    var row: usize = 1;

    while (right_iter.next()) |right_char| : (row += 1) {
        var prev_diag = array[0];
        array[0] = row;

        var left_iter = Utf8Iterator.init(left_bytes);
        var col: usize = 1;

        while (left_iter.next()) |left_char| : (col += 1) {
            const cost = if (left_char == right_char) @as(usize, 0) else @as(usize, 1);
            const temp = array[col];

            array[col] = @min(@min(array[col] + 1, // deletion
                array[col - 1] + 1 // insertion
                ), prev_diag + cost); // substitution

            prev_diag = temp;
        }

        if (max != null and array[ll] >= max.?) return max.?;
    }

    return array[ll];
}

// Tests taken from https://raw.githubusercontent.com/sindresorhus/leven/refs/heads/main/test.js
test "basic tests" {
    const allocator = testing.allocator;

    try testing.expectEqual(@as(usize, 1), try levenshtein(allocator, "b", "a", null));
    try testing.expectEqual(@as(usize, 1), try levenshtein(allocator, "ab", "ac", null));
    try testing.expectEqual(@as(usize, 1), try levenshtein(allocator, "ac", "bc", null));
    try testing.expectEqual(@as(usize, 1), try levenshtein(allocator, "abc", "axc", null));
    try testing.expectEqual(@as(usize, 3), try levenshtein(allocator, "kitten", "sitting", null));
    try testing.expectEqual(@as(usize, 6), try levenshtein(allocator, "xabxcdxxefxgx", "1ab2cd34ef5g6", null));
    try testing.expectEqual(@as(usize, 2), try levenshtein(allocator, "cat", "cow", null));
    try testing.expectEqual(@as(usize, 6), try levenshtein(allocator, "xabxcdxxefxgx", "abcdefg", null));
    try testing.expectEqual(@as(usize, 7), try levenshtein(allocator, "javawasneat", "scalaisgreat", null));
    try testing.expectEqual(@as(usize, 3), try levenshtein(allocator, "example", "samples", null));
    try testing.expectEqual(@as(usize, 6), try levenshtein(allocator, "sturgeon", "urgently", null));
    try testing.expectEqual(@as(usize, 6), try levenshtein(allocator, "levenshtein", "frankenstein", null));
    try testing.expectEqual(@as(usize, 5), try levenshtein(allocator, "distance", "difference", null));
    try testing.expectEqual(@as(usize, 2), try levenshtein(allocator, "因為我是中國人所以我會說中文", "因為我是英國人所以我會說英文", null));
}
