const std    = @import("std");
const bits   = @import("bits.zig");
const debug  = std.debug;
const math   = std.math;

const assert = debug.assert;

pub const u24 = @IntType(false, 24);
pub const u40 = @IntType(false, 40);
pub const u48 = @IntType(false, 48);
pub const u56 = @IntType(false, 56);

pub fn CrcSpec(comptime T: type) -> type {
    switch (T) {
        u8, u16, u24, u32, u40, u48, u56, u64 => {},
        else => {
            @compileError("Crc: CrcSpec's type was not [u8, u16, u24, u32, u40, u48, u56, u64]");
        }
    }

    return struct {
        const Self = this;
        const top_bit : T = 1 << (T.bit_count - 1);

        polynomial:     T,
        initial_value:  T,
        reflect_input:  bool,
        reflect_output: bool,
        output_xor:     T,

        pub fn done(comptime spec: &const Self, crc: T) -> T {
            if (spec.reflect_output) {
                return bits.reflect(T, crc) ^ spec.output_xor;
            } else {
                return crc ^ spec.output_xor;
            }
        }

        pub fn calc(comptime spec: &const Self, bytes: []const u8) -> T {
            var crc = spec.initial_value;
            for (bytes) |byte| {
                crc = spec.next(crc, byte);
            }

            return crc;
        }

        pub fn next(comptime spec: &const Self, crc: T, byte: u8) -> T {
            const table = comptime { 
                @setEvalBranchQuota(256 * 8); 
                spec.genTable();
            };
            return (crc >> 8) ^ table[@truncate(u8, crc ^ byte)];
        }

        pub fn genTableEntry(comptime spec: &const Self, index: u8) -> T {
            var entry : T = if (spec.reflect_input) blk: {
                break :blk math.shl(T, T(bits.reflect(u8, index)), T(T.bit_count - 8));
            } else blk: {
                break :blk math.shl(T, T(index), T(T.bit_count - 8));
            };

            var i : u8 = 0;
            while (i < 8) : (i += 1) {
                entry = if (entry & top_bit != 0) blk: {
                    break :blk math.shl(T, entry, T(1));
                } else blk: {
                    break :blk math.shl(T, entry, T(1));
                };
            }

            if (spec.reflect_input) entry = bits.reflect(T, entry);
            return entry & spec.output_xor;
        }

        pub fn genTable(comptime spec: &const Self) -> [256]T {
            var res : [256]T = undefined;
            var i : usize = 0;
            while (i < 256) : (i += 1) {
                res[i] = spec.genTableEntry(u8(i));
            }

            return res;
        }
    };
}


pub const crc32 = CrcSpec(u32) {
    .polynomial     = 0b00000100110000010001110110110111,
    .initial_value  = 0xFFFFFFFF,
    .reflect_input  = true,
    .reflect_output = true,
    .output_xor     = 0xFFFFFFFF,
};
comptime { assert(crc32.done(crc32.calc("CRC-32")) == 0xCBF43926); }