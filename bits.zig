const std    = @import("std");

const debug  = std.debug;
const rand   = std.rand;
const math   = std.math;

const assert = debug.assert;

pub fn Log2T(comptime T: type) -> type {
    return @IntType(false, comptime usize(math.ceil(math.log2(f64(T.bit_count)))));
}

pub fn mostSignificant(value: u64) -> u6 {
    var tmp = value >> 1;
    var index : u6 = 0;
    while (tmp != 0) {
        tmp >>= 1;
        index += 1;
    }

    return index;
}

test "crc.bits.mostSignificant" {
    var noiser = rand.Rand.init(0);
    var i : usize = 0;
    while (i < @sizeOf(u64) * 8) : (i += 1) {
        const msb = @shlExact(u64(1), u6(i));
        const noise = noiser.range(u64, 0, msb);
        assert(mostSignificant(msb | noise) == i);
    }
}

pub fn reflect(comptime T: type, value: T) -> T {
    const bits = @sizeOf(T) * 8;
    var tmp = value;
    var result : T = 0;
    var i : usize = 0;

    while (i < bits) : (i += 1) {
        result |= @shlExact(tmp & 1, Log2T(T)((bits - 1) - i));
        tmp >>= 1;
    }

    return result;
}

test "crc.bits.reflect" {
    const cases = [][2]u8 {
        []u8 { 0b10000000, 0b00000001 },
        []u8 { 0b00000001, 0b10000000 },
        []u8 { 0b01010101, 0b10101010 },
        []u8 { 0b11001100, 0b00110011 },
        []u8 { 0b11111111, 0b11111111 },
        []u8 { 0b00000000, 0b00000000 },
    };

    for (cases) |case| {
        assert(reflect(u8, case[0]) == case[1]);
    }
}