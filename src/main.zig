const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

// cube coordinates:
// 3 major axis: q, r, s
// Slice through cube on plane: q + r + s = 0
//
//   /\
//  /  \
// |    |  q->  /s   r\
// |    |       *      *
//  \  /
//   \/

const Hex = struct {
    q: Energy,
    s: Energy,
    r: Energy,
    pub fn energyTotal(self: @This()) f64 {
        const q_total = @intToFloat(f64, @as(u32, self.q[0]) + self.q[1]);
        const s_total = @intToFloat(f64, @as(u32, self.s[0]) + self.s[1]);
        const r_total = @intToFloat(f64, @as(u32, self.r[0]) + self.r[1]);
        // const u16_max = @intToFloat(f64, ~@as(u16, 0));
        const avg = (q_total + s_total + r_total); // / (u16_max * 6.0);
        if (avg == 0.0) {
            return 0.0;
        }
        return (@log(avg)) / 1.0;
    }
};

// Energy on an axis in both directions [0]: rev | [1]: fwd
const Energy = [2]u16;
// s coord can be inferred s = -q -r
const AxialPoint = struct { q: usize, r: usize };
const SquarePoint = struct { x: usize, y: usize };

pub fn main() anyerror!void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var arg_iter = std.process.args();
    _ = arg_iter.skip();
    var iter_max: usize = 0;
    if (arg_iter.next(gpa)) |arg1| {
        const arg1_str = (try arg1);
        iter_max = try std.fmt.parseInt(usize, arg1_str, 0);
        defer gpa.free(arg1_str);
    }

    var map = try newMap(arena, 70, 70);
    var map_new = try newMap(arena, 70, 70);

    const hex = map.getHex(AxialPoint{ .q = 20, .r = 25 });
    hex.q[0] = 0xffff;
    hex.q[1] = 0xffff;
    hex.s[0] = 0xffff;
    hex.s[1] = 0xffff;
    hex.r[0] = 0xffff;
    hex.r[1] = 0xffff;

    const hex2 = map.getHex(AxialPoint{ .q = 30, .r = 25 });
    hex2.q[0] = 0xffff;
    hex2.q[1] = 0xffff;
    hex2.s[0] = 0xffff;
    hex2.s[1] = 0xffff;
    hex2.r[0] = 0xffff;
    hex2.r[1] = 0xffff;

    //renderMap(&map);
    ////
    var iter: usize = 0;
    while (iter < iter_max) {
        //std.debug.print("{s}\n", .{[_:0]u8{'-'} ** 80});
        nextIteration(&map, &map_new);

        //renderMap(&map_new);

        std.mem.swap(Map, &map, &map_new);
        map_new.reset();
        iter += 1;
    }

    const cwd = fs.cwd();
    var f = try cwd.createFile("test.ppm", fs.File.CreateFlags{});
    defer f.close();

    const width: usize = 800;
    const height: usize = 600;

    try f.writeAll("P6\n");
    try std.fmt.format(f.writer(), "{d} {d}\n", .{ width, height });
    try f.writeAll("255\n");
    var pixel_map = [_]u8{0} ** (width * height * 3);
    renderSquare(&map, width, height, &pixel_map);
    try f.writeAll(&pixel_map);
}
fn renderMap(map: *Map) void {
    var result: [80][80:0]u8 = [_][80:0]u8{[_:0]u8{' '} ** 80} ** 80;
    var q: usize = 0;
    while (q < 40) {
        var r: usize = 0;
        while (r < 50) {
            const ap = AxialPoint{ .q = q, .r = r };
            const p = axialToSquare(ap);
            const hex_energy = map.getHex(ap).energyTotal();
            if (hex_energy < 1) {
                result[p.y][p.x] = '.';
            } else if (hex_energy < 2) {
                result[p.y][p.x] = ',';
            } else if (hex_energy < 5) {
                result[p.y][p.x] = '*';
            } else if (hex_energy < 10) {
                result[p.y][p.x] = '0';
            } else if (hex_energy < 20) {
                result[p.y][p.x] = '@';
            } else {
                result[p.y][p.x] = '#';
            }
            r += 1;
        }
        q += 1;
    }
    for (result) |str| {
        std.debug.print("{s}\n", .{str});
    }
}

fn renderSquare(map: *Map, width: usize, height: usize, pixels: []u8) void {
    var y: usize = 0;
    while (y < height) {
        var x: usize = 0;
        while (x < width) {
            const pix_idx = (y * width * 3) + (x * 3);
            if (squareToAxial(SquarePoint{ .x = x, .y = y })) |ap| {
                if (ap.q < map.length and ap.r < map.height) {
                    const hex_energy = map.getHex(ap).energyTotal();
                    pixels[pix_idx] = @floatToInt(u8, hex_energy * 2.5);
                    pixels[pix_idx + 1] = @floatToInt(u8, hex_energy * 2.5);
                    pixels[pix_idx + 2] = @floatToInt(u8, hex_energy * 2.5);
                } else {
                    pixels[pix_idx] = 10;
                    pixels[pix_idx + 1] = 0;
                    pixels[pix_idx + 2] = 0;
                }
            } else {
                pixels[pix_idx] = 10;
                pixels[pix_idx + 1] = 0;
                pixels[pix_idx + 2] = 0;
            }
            x += 1;
        }
        y += 1;
    }
}

fn newMap(alloc: Allocator, length: usize, height: usize) !Map {
    var data = try alloc.alloc([]Hex, length);
    for (data) |_, q| {
        data[q] = try alloc.alloc(Hex, height);
        for (data[q]) |_, r| {
            data[q][r] = std.mem.zeroInit(Hex, .{});
        }
    }
    return Map{ .hexes = data, .length = length, .height = height };
}

fn axialToSquare(ap: AxialPoint) SquarePoint {
    return SquarePoint{ .x = 1 * ((std.math.sqrt(3) * ap.q) + ((std.math.sqrt(3) * ap.r) / 2)), .y = 1 * ((3 * ap.r) / 2) };
}

fn squareToAxial(sp: SquarePoint) ?AxialPoint {
    const size: f64 = 5;
    const q_f = ((std.math.sqrt(3.0) / 3.0) * @intToFloat(f64, sp.x) - (1.0 / 3.0) * @intToFloat(f64, sp.y)) / size;
    const r_f = ((2.0 / 3.0) * @intToFloat(f64, sp.y)) / size;
    if (q_f < 0.0 or r_f < 0.0) {
        return null;
    }
    const s_f = -q_f - r_f;

    var q = @round(q_f);
    var r = @round(r_f);
    var s = @round(s_f);

    const dq = std.math.absFloat(q - q_f);
    const dr = std.math.absFloat(r - r_f);
    const ds = std.math.absFloat(s - s_f);

    if (dq > dr and dq > ds) {
        q = -r - s;
    } else if (dr > ds) {
        r = -q - s;
    }

    return AxialPoint{ .q = @floatToInt(usize, q), .r = @floatToInt(usize, r) };
}

fn nextIteration(old: *Map, new: *Map) void {
    std.debug.assert(old.length == new.length);
    std.debug.assert(old.height == new.height);
    var pos = AxialPoint{ .q = 0, .r = 0 };
    while (pos.q < old.length) {
        while (pos.r < old.height) {
            const current = old.getHex(pos);
            const nbs = new.getNeighbours(pos);
            const q_rev = current.q[0] / 3;
            const q_fwd = current.q[1] / 3;
            const s_rev = current.s[0] / 3;
            const s_fwd = current.s[1] / 3;
            const r_rev = current.r[0] / 3;
            const r_fwd = current.r[1] / 3;

            if (nbs[0]) |n| {
                n.r[0] +|= q_rev +| s_rev +| r_rev;
            }
            if (nbs[1]) |n| {
                n.s[0] +|= q_fwd +| s_rev +| r_rev;
            }
            if (nbs[2]) |n| {
                n.q[1] +|= q_fwd +| s_rev +| r_fwd;
            }
            if (nbs[3]) |n| {
                n.r[1] +|= q_fwd +| s_fwd +| r_fwd;
            }
            if (nbs[4]) |n| {
                n.s[1] +|= q_rev +| s_fwd +| r_fwd;
            }
            if (nbs[5]) |n| {
                n.q[0] +|= q_rev +| s_fwd +| r_rev;
            }

            pos.r += 1;
        }
        pos.q += 1;
        pos.r = 0;
    }
}

const Map = struct {
    hexes: [][]Hex,
    length: usize,
    height: usize,
    pub fn getHex(self: Map, pos: AxialPoint) *Hex {
        return &self.hexes[pos.q][pos.r];
    }

    // Neighbours are returned clockwise starting at q:0 r:-1
    pub fn getNeighbours(self: Map, pos: AxialPoint) [6]?*Hex {
        std.debug.assert(pos.q < self.length);
        std.debug.assert(pos.r < self.height);
        return [6]?*Hex{
            if (pos.r > 0) &self.hexes[pos.q][pos.r - 1] else null,
            if (pos.r > 0 and (pos.q + 1) < self.length) &self.hexes[pos.q + 1][pos.r - 1] else null,
            if ((pos.q + 1) < self.length) &self.hexes[pos.q + 1][pos.r] else null,
            if ((pos.r + 1) < self.height) &self.hexes[pos.q][pos.r + 1] else null,
            if (pos.q > 0 and (pos.r + 1) < self.height) &self.hexes[pos.q - 1][pos.r + 1] else null,
            if (pos.q > 0) &self.hexes[pos.q - 1][pos.r] else null,
        };
    }

    pub fn reset(self: @This()) void {
        for (self.hexes) |_, q| {
            for (self.hexes[q]) |_, r| {
                self.hexes[q][r] = std.mem.zeroInit(Hex, .{});
            }
        }
    }
};
