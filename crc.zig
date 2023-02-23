const std = @import("std");

const math = std.math;
const testing = std.testing;

fn reflect(comptime UInt: type, data: UInt) UInt {
    const bits = @typeInfo(UInt).Int.bits;
    var res: UInt = 0;
    var tmp = data;
    var bit: usize = 0;
    while (bit < bits) : (bit += 1) {
        if (tmp & 1 != 0) {
            res |= math.shl(UInt, 1, ((bits - 1) - bit));
        }

        tmp >>= 1;
    }

    return res;
}

fn reflectIf(comptime K: type, predicate: bool, data: K) K {
    return if (predicate) reflect(K, data) else data;
}

test "reflect" {
    try testing.expectEqual(@as(u8, 0b10000000), reflect(u8, 0b00000001));
    try testing.expectEqual(@as(u8, 0b00000001), reflect(u8, 0b10000000));
}

pub const crcspec_init_backward_cycles = 20000;

pub fn Spec(comptime UInt: type) type {
    return struct {
        polynomial: UInt,
        initial_value: UInt,
        xor_value: UInt,
        reflect_data: bool,
        reflect_remainder: bool,
        table: [256]UInt = undefined,

        pub fn init(spec: @This()) @This() {
            var res = spec;
            const bits = @typeInfo(UInt).Int.bits;
            const top_bit = @as(UInt, 1) << (bits - 1);

            for (&res.table, 0..) |*entry, i| {
                var crc = @intCast(UInt, i) << (bits - 8);

                var bit: usize = 0;
                while (bit < 8) : (bit += 1) {
                    if (crc & top_bit != 0) {
                        crc = math.shl(UInt, crc, @as(UInt, 1)) ^ res.polynomial;
                    } else {
                        crc = math.shl(UInt, crc, @as(UInt, 1));
                    }
                }

                entry.* = crc;
            }

            return res;
        }

        pub fn checksum(spec: @This(), bytes: []const u8) UInt {
            var crc = spec.processer();
            crc.update(bytes);
            return crc.final();
        }

        pub fn processer(spec: @This()) Crc(UInt) {
            return Crc(UInt).init(spec);
        }
    };
}

pub fn Crc(comptime UInt: type) type {
    return struct {
        const bits = @typeInfo(UInt).Int.bits;

        spec: Spec(UInt),
        remainder: UInt,

        pub fn init(spec: Spec(UInt)) @This() {
            return @This(){
                .spec = spec,
                .remainder = spec.initial_value,
            };
        }

        pub fn update(crc: *@This(), bytes: []const u8) void {
            for (bytes) |byte| {
                const reflected_byte = reflectIf(u8, crc.spec.reflect_data, byte);
                const entry = reflected_byte ^ (crc.remainder >> (bits - 8));
                crc.remainder = crc.spec.table[entry] ^ math.shl(UInt, crc.remainder, 8);
            }
        }

        pub fn final(crc: @This()) UInt {
            const reflected = reflectIf(UInt, crc.spec.reflect_remainder, crc.remainder);
            return reflected ^ crc.spec.xor_value;
        }
    };
}

// Specs below gotten from http://reveng.sourceforge.net/crc-catalogue/all.htm
pub const crc8 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk Spec(u8).init(.{
        .polynomial = 0x07,
        .initial_value = 0x00,
        .xor_value = 0x00,
        .reflect_data = false,
        .reflect_remainder = false,
    });
};

test "crc8" {
    try testing.expectEqual(@as(u8, 0xF4), crc8.checksum("123456789"));
}

pub const crc16 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk Spec(u16).init(.{
        .polynomial = 0x8005,
        .initial_value = 0x0000,
        .xor_value = 0x0000,
        .reflect_data = true,
        .reflect_remainder = true,
    });
};

test "crc16" {
    try testing.expectEqual(@as(u16, 0xBB3D), crc16.checksum("123456789"));
}

pub const crc32 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk Spec(u32).init(.{
        .polynomial = 0x04C11DB7,
        .initial_value = 0xFFFFFFFF,
        .xor_value = 0xFFFFFFFF,
        .reflect_data = true,
        .reflect_remainder = true,
    });
};

test "crc32" {
    try testing.expectEqual(@as(u32, 0xCBF43926), crc32.checksum("123456789"));
}

pub const crc64 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk Spec(u64).init(.{
        .polynomial = 0x42F0E1EBA9EA3693,
        .initial_value = 0x0000000000000000,
        .xor_value = 0x0000000000000000,
        .reflect_data = false,
        .reflect_remainder = false,
    });
};

test "crc64" {
    try testing.expectEqual(@as(u64, 0x6C40DF5F0B497347), crc64.checksum("123456789"));
}
