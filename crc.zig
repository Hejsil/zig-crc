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

test "crc.reflect" {
    try testing.expectEqual(@as(u8, 0b10000000), reflect(u8, 0b00000001));
    try testing.expectEqual(@as(u8, 0b00000001), reflect(u8, 0b10000000));
}

pub const crcspec_init_backward_cycles = 20000;

pub const Reflect = struct {
    pub const Data = enum {
        True,
        False,
    };

    pub const Remainder = enum {
        True,
        False,
    };
};

pub fn CrcSpec(comptime UInt: type) type {
    return struct {
        polynomial: UInt,
        initial_value: UInt,
        xor_value: UInt,
        reflect_data: bool,
        reflect_remainder: bool,
        table: [256]UInt = undefined,

        pub fn init(polynomial: UInt, initial_value: UInt, xor_value: UInt, reflect_data: bool, reflect_remainder: bool) CrcSpec(UInt) {
            var res = @This(){
                .polynomial = polynomial,
                .initial_value = initial_value,
                .xor_value = xor_value,
                .reflect_data = reflect_data,
                .reflect_remainder = reflect_remainder,
                .table = undefined,
            };

            const bits = @typeInfo(UInt).Int.bits;
            const top_bit = @as(UInt, 1) << (bits - 1);

            for (res.table) |*entry, i| {
                var crc = @intCast(UInt, i) << (bits - 8);

                var bit: usize = 0;
                while (bit < 8) : (bit += 1) {
                    if (crc & top_bit != 0) {
                        crc = math.shl(UInt, crc, @as(UInt, 1)) ^ polynomial;
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

        spec: CrcSpec(UInt),
        remainder: UInt,

        pub fn init(spec: CrcSpec(UInt)) @This() {
            return @This(){
                .spec = spec,
                .remainder = spec.initial_value,
            };
        }

        fn reflect_if(comptime K: type, ref: bool, data: K) K {
            if (ref) {
                return reflect(K, data);
            } else {
                return data;
            }
        }

        pub fn update(crc: *@This(), bytes: []const u8) void {
            for (bytes) |byte| {
                const entry = reflect_if(u8, crc.spec.reflect_data, byte) ^ (crc.remainder >> (bits - 8));
                crc.remainder = crc.spec.table[entry] ^ math.shl(UInt, crc.remainder, @as(UInt, 8));
            }
        }

        pub fn final(crc: @This()) UInt {
            const reflected = reflect_if(UInt, crc.spec.reflect_remainder, crc.remainder);
            return reflected ^ crc.spec.xor_value;
        }
    };
}

// Specs below gotten from http://reveng.sourceforge.net/crc-catalogue/all.htm
pub const crc8 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u8).init(0x07, 0x00, 0x00, false, false);
};

test "crc.crc8" {
    try testing.expectEqual(@as(u8, 0xF4), crc8.checksum("123456789"));
}

pub const crc16 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u16).init(0x8005, 0x0000, 0x0000, true, true);
};

test "crc.crc16" {
    try testing.expectEqual(@as(u16, 0xBB3D), crc16.checksum("123456789"));
}

pub const crc32 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u32).init(0x04C11DB7, 0xFFFFFFFF, 0xFFFFFFFF, true, true);
};

test "crc.crc32" {
    try testing.expectEqual(@as(u32, 0xCBF43926), crc32.checksum("123456789"));
}

pub const crc64 = blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u64).init(0x42F0E1EBA9EA3693, 0x0000000000000000, 0x0000000000000000, false, false);
};

test "crc.crc64" {
    try testing.expectEqual(@as(u64, 0x6C40DF5F0B497347), crc64.checksum("123456789"));
}
