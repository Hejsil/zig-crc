const std = @import("std");

const math  = std.math;
const debug = std.debug;

const assert = debug.assert;

fn reflect(comptime T: type, data: T) T {
    var res : T = 0;
    var tmp = data;
    var bit : usize = 0;
    while (bit < T.bit_count) : (bit += 1) {
        if (tmp & 1 != 0) {
            res |= math.shl(T, 1, ((T.bit_count - 1) - bit));
        }

        tmp >>= 1;
    }

    return res;
}

test "crc.reflect" {
    assert(reflect(u8, 0b00000001) == 0b10000000);
    assert(reflect(u8, 0b10000000) == 0b00000001);
}

// // 256
// for (res.table) |*entry, i| {
//     var crc = T(i) << (T.bit_count - 8);
//
//     // 256 * 8 * (1)
//     var bit : usize = 0;
//     while (bit < 8) : (bit += 1) {
//         // 256 * 8 * (1 + 1)
//         if (crc & top_bit != 0) {
//             // 256 * 8 * (1 + 1 + 3)
//             crc = math.shl(T, crc, T(1)) ^ polynomial;
//         } else {
//             crc = math.shl(T, crc, T(1));
//         }
//     }
//
//     *entry = crc;
// }
pub const crcspec_init_backward_cycles = 256 * 8 * (1 + 1 + 3);

pub fn CrcSpec(comptime T: type) type {
    return struct {
        const Self = this;

        polynomial: T,
        initial_value: T,
        xor_value: T,
        reflect_data: bool,
        reflect_remainder: bool,
        table: [256]T,

        pub fn init(polynomial: T, initial_value: T, xor_value: T, reflect_data: bool, reflect_remainder: bool) CrcSpec(T) {
            var res = Self {
                .polynomial = polynomial,
                .initial_value = initial_value,
                .xor_value = xor_value,
                .reflect_data = reflect_data,
                .reflect_remainder = reflect_remainder,
                .table = undefined,
            };

            const top_bit = T(1) << (T.bit_count - 1);

            for (res.table) |*entry, i| {
                var crc = T(i) << (T.bit_count - 8);

                var bit : usize = 0;
                while (bit < 8) : (bit += 1) {
                    if (crc & top_bit != 0) {
                        crc = math.shl(T, crc, T(1)) ^ polynomial;
                    } else {
                        crc = math.shl(T, crc, T(1));
                    }
                }

                *entry = crc;
            }

            return res;
        }

        pub fn checksum(spec: &const Self, bytes: []const u8) T {
            var crc = spec.processer();
            crc.update(bytes);
            return crc.final();
        }

        pub fn processer(spec: &const Self) Crc(T) {
            return Crc(T).init(spec);
        }
    };
}

pub fn Crc(comptime T: type) type {
    return struct {
        const Self = this;

        spec: CrcSpec(T),
        remainder: T,

        pub fn init(spec: &const CrcSpec(T)) Self {
            return Self {
                .spec = *spec,
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

        pub fn update(crc: &Self, bytes: []const u8) void {
            const reflect_data = crc.spec.reflect_data;

            for (bytes) |byte| {
                const entry = reflect_if(u8, reflect_data, byte) ^ (crc.remainder >> (T.bit_count - 8));
                crc.remainder = crc.spec.table[entry] ^ math.shl(T, crc.remainder, T(8));
            }
        }

        pub fn final(crc: &const Self) T {
            const reflected = reflect_if(T, crc.spec.reflect_remainder, crc.remainder);
            return reflected ^ crc.spec.xor_value;
        }
    };
}

// Specs below gotten from http://reveng.sourceforge.net/crc-catalogue/all.htm
pub const crc8 = comptime blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u8).init(0x07, 0x00, 0x00, false, false);
};

test "crc.crc8" {
    assert(crc8.checksum("123456789") == 0xF4);
}

pub const crc16 = comptime blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u16).init(0x8005, 0x0000, 0x0000, true, true);
};

test "crc.crc16" {
    assert(crc16.checksum("123456789") == 0xBB3D);
}

pub const crc32 = comptime blk: {
    @setEvalBranchQuota(crcspec_init_backward_cycles);
    break :blk CrcSpec(u32).init(0x04C11DB7, 0xFFFFFFFF, 0xFFFFFFFF, true, true);
};

test "crc.crc32" {
    assert(crc32.checksum("123456789") == 0xCBF43926);
}

// TODO: crc64 failes. Figure out why
//pub const crc64 = comptime blk: {
//    @setEvalBranchQuota(crcspec_init_backward_cycles);
//    break :blk CrcSpec(u64).init(0x42F0E1EBA9EA3693, 0x0000000000000000, 0x0000000000000000, false, false);
//};
//
//test "crc.crc64" {
//    assert(crc64.checksum("123456789") == 0x6C40DF5F0B497347);
//}
