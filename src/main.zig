//! A joke that has gone a bit too far in my opinion

// Used to lookdown on python and the 1000s in libraries people use, but look at me now, using other people's code
const std = @import("std");
const fig = @import("ziglet");
const cal = @import("datetime").datetime;

// FIGlet font files
const fnt_fileBig: []const u8 = @embedFile("doom.flf");
const fnt_fileSml: []const u8 = @embedFile("mini.flf");
// DoB Files
const dob_staff: []const u8 = @embedFile("dob.dat");
const dob_known: []const u8 = @embedFile("dobKnw.dat");

// You may pull this struct into the dobEntry struct, but then the LSP gets lost in the woods
const Date = struct {
    day: u32,
    month: u32,
    year: u32
};
const dobEntry = struct {
    date: cal.Date,
    name: []const u8,
};

// Just pick a power of two and hope you don't run out of memory, atleast it's fast
var fba_buf: [4096]u8 = undefined;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const header_width = try printHeader(allocator, "ICE. Birthdays", stdout);
    try stdout.print("DoBIce v0.0.1 {} By Daniel\n", .{header_width});

    var fntSml = try fig.DefaultFont.init(allocator, fnt_fileSml);
    defer fntSml.deinit(allocator);

    var fba = std.heap.FixedBufferAllocator.init(&fba_buf);
    const fba_alloc = fba.allocator();
    var dob_staff_list = std.ArrayList(dobEntry).init(fba_alloc);
    defer dob_staff_list.deinit();
    var dob_known_list = std.ArrayList(dobEntry).init(fba_alloc);
    defer dob_known_list.deinit();

    // Yes I know I am cheating here, but I don't know zig well enough to do dynamic parsing of files (lazy)
    try parseDobFile(&dob_staff_list, dob_staff);
    try parseDobFile(&dob_known_list, dob_known);
    
    // Excuse me, but what the fuck? I don't know why this even works.
    std.mem.sort(dobEntry, dob_staff_list.items, {}, comptime dobLessThan);
    std.mem.sort(dobEntry, dob_known_list.items, {}, comptime dobLessThan);

    var cur_month: u4 = 1;
    var prev_month: u4 = 12;
    var printed_banner: bool = false;
    for (dob_staff_list.items,dob_known_list.items) |entry,knwEnt| {
        cur_month = entry.date.month;
        if (prev_month != cur_month) {
            printed_banner = false;
        }
        if (!printed_banner) {
            try printMonth(allocator, &fntSml, entry.date, header_width, stdout);
            printed_banner = true;
        }
        try stdout.print("{s} {} --- {s} --- Shares bday with: {s} (Born on {s} {} {s} {})\n", .{entry.date.weekdayName(),
            entry.date.day,
            entry.name,
            knwEnt.name,
            knwEnt.date.weekdayName(),
            knwEnt.date.day,
            knwEnt.date.monthName(),
            knwEnt.date.year,
        });

        prev_month = entry.date.month;
    }

    try bw.flush(); // Don't forget to flush!
}

fn printHeader(alloc: std.mem.Allocator, text: []const u8, writer: anytype) !usize {
    var fntBig = try fig.DefaultFont.init(alloc, fnt_fileBig);
    defer fntBig.deinit(alloc);

    const result = try fntBig.formatter().formatTextAsLines(alloc, text, .{});
    defer {
        for (result) |line| alloc.free(line);
        alloc.free(result);
    }
   
    var retval: usize = 0;
    for (result) |line| {
        try writer.print("{s}\n", .{line});
        if (line.len >= retval) {
            retval = line.len;
        }
    }
    return retval;
}

fn printMonth(alloc: std.mem.Allocator, fnt: *fig.DefaultFont, date: cal.Date, txt_width: usize, writer: anytype) !void {
    const result = try fnt.formatter().formatTextAsLines(alloc, date.monthName(), .{});
    defer {
        for (result) |line| alloc.free(line);
        alloc.free(result);
    }
    const pad_width = txt_width/2 - result[0].len/2;
    for (result) |line| {
        for (0..pad_width) |i| {
            _ = i;
            try writer.print(" ", .{});
        }
        try writer.print("{s}\n", .{line});
    }
}

fn parseDobFile(dob_list: *std.ArrayList(dobEntry), dob_file: []const u8, ) !void {
    var dob_i = std.mem.splitAny(u8, dob_file, "\n");
    while (dob_i.next()) |line| {
        var date : Date = undefined;
        var it = std.mem.tokenizeAny(u8, line, "/,");
        if (it.peek() == null) break;
        date.day = try std.fmt.parseInt(u32, it.next() orelse "1", 10);
        date.month = try std.fmt.parseInt(u32, it.next() orelse "1", 10);
        date.year = try std.fmt.parseInt(u32, it.next() orelse "1", 10);
        
        const entry: dobEntry = .{ .date = try cal.Date.create(date.year, date.month, date.day),
        .name = it.peek() orelse "nobody"};

        try dob_list.append(entry);
    }
}

fn dobLessThan(potato: void, lhs: dobEntry, rhs: dobEntry) bool{
    // Force to current year to ignore the year in the sorting alg
    var lhs_mod: dobEntry = lhs;
    var rhs_mod: dobEntry = rhs;
    lhs_mod.date.year = 2025;
    rhs_mod.date.year = 2025;
    
    const comparison = cal.Date.cmp(lhs_mod.date, rhs_mod.date);
    _ = potato;

    switch (comparison) {
        .eq => return false,
        .gt => return false,
        .lt => return true,
    }
}
