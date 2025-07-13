# levenshtein

Fast, UTF-8 aware Levenshtein distance implementation for Zig.

## Features

- **UTF-8 Support**: Correctly handles Unicode code points (emojis, accented characters, etc.)
- **Memory Efficient**: Zero-allocation string processing with minimal working memory
- **Early Termination**: Optional maximum distance threshold for performance
- **Zero Dependencies**: Uses only Zig's standard library

## Installation

```bash
zig fetch --save git+https://github.com/unorsk/levenshtein.git
```

Add this to your build.zig
```zig
    const levenshtein = b.dependency("levenshtein", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("levenshtein", levenshtein.module("levenshtein"));
```

## Usage

```zig
const std = @import("std");
const levenshtein = @import("levenshtein");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Basic usage
    const distance = try levenshtein.levenshtein(allocator, "kitten", "sitting", null);
    std.debug.print("Distance: {}\n", .{distance}); // Output: 3

    // UTF-8 strings work correctly
    const emoji_distance = try levenshtein.levenshtein(allocator, "😊", "😢", null);
    std.debug.print("Emoji distance: {}\n", .{emoji_distance}); // Output: 1

    // Early termination with max distance
    const limited = try levenshtein.levenshtein(allocator, "very long string", "another long string", 5);
    std.debug.print("Limited distance: {}\n", .{limited}); // Output: 5 (stopped early)
}
```

## API

```zig
pub fn levenshtein(
    allocator: std.mem.Allocator, 
    a: []const u8, 
    b: []const u8, 
    max: ?usize
) !usize
```

**Parameters:**
- `allocator`: Memory allocator for internal working arrays
- `a`, `b`: UTF-8 strings to compare
- `max`: Optional maximum distance (returns early if exceeded)

**Returns:** Levenshtein distance as `usize`

## License

MIT