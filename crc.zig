const std    = @import("std");
const debug  = std.debug;
const assert = debug.assert;

pub const CrcSpec = struct {
	name: []const u8,
	name_checksum: usize,

	width: u8,
	polynomial: usize,
	initial_value: usize,
	reflect_input: bool,
	reflect_output: bool,
	output_xor: usize,

	pub fn isValid(comptime spec: &const CrcSpec) -> bool {
		return crc(spec, spec.name) == spec.name_checksum;
	}
};

pub const crc32 = CrcSpec {
	.name           = "CRC-32",
	.name_checksum  = 0xCBF43926,

	.width          = 32,
	.polynomial     = 0b00000100110000010001110110110111,
	.initial_value  = 0xFFFFFFFF,
	.reflect_input  = true,
	.reflect_output = true,
	.output_xor     = 0xFFFFFFFF,
};

fn mostSignificantBit(value: usize) -> u8 {
	var index = 0;
	while (value != 0) {
		index += 1;
		value >>= 1;
	}

	return index;
}

pub fn crc(comptime spec: &const CrcSpec, bytes: []const u8) -> @IntType(false, spec.width) {
	comptime {
		assert(msb)
		assert(crc(spec, spec.name) == spec.name_checksum);
	}
}