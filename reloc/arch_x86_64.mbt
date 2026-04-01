///| x86_64 relocation handlers

///|
/// x86_64 relocation types
const R_X86_64_NONE : UInt = 0

///|
const R_X86_64_64 : UInt = 1

///|
const R_X86_64_PC32 : UInt = 2

///|
const R_X86_64_PLT32 : UInt = 4

///|
const R_X86_64_GLOB_DAT : UInt = 6

///|
const R_X86_64_JUMP_SLOT : UInt = 7

///|
const R_X86_64_RELATIVE : UInt = 8

///|
const R_X86_64_GOTPCREL : UInt = 9

///|
const R_X86_64_32 : UInt = 10

///|
const R_X86_64_32S : UInt = 11

///|
const R_X86_64_16 : UInt = 12

///|
const R_X86_64_PC8 : UInt = 14

///|
const R_X86_64_8 : UInt = 15

///|
const R_X86_64_PC64 : UInt = 24

///|
const R_X86_64_GOTPC64 : UInt = 26

///|
const R_X86_64_GOTPCREL64 : UInt = 28

///|
const R_X86_64_64_32 : UInt = 38

///|
/// Apply x86_64 relocation
pub fn apply_x86_64_reloc(
  bytes : Bytes,
  offset : UInt64,
  rel_type : UInt,
  sym_value : UInt64,
  addend : Int64,
  pc_offset : UInt64,
) -> Bytes raise @ir.RelocError {
  match rel_type {
    R_X86_64_NONE => bytes
    R_X86_64_64 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      patch_u64(bytes, offset, result)
    }
    R_X86_64_PC32 | R_X86_64_PLT32 | R_X86_64_GOTPCREL => {
      let result = sym_value.reinterpret_as_int64() +
        addend -
        pc_offset.reinterpret_as_int64()
      if result < -2147483648L || result > 2147483647L {
        raise RelocOverflow("R_X86_64_PC32/PLT32/GOTPCREL overflow")
      }
      patch_u32(bytes, offset, result.reinterpret_as_uint64())
    }
    R_X86_64_32 | R_X86_64_64_32 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      if result > 0xffff_ffffUL {
        raise RelocOverflow("R_X86_64_32 overflow")
      }
      patch_u32(bytes, offset, result)
    }
    R_X86_64_32S => {
      let result = sym_value.reinterpret_as_int64() + addend
      if result < -2147483648L || result > 2147483647L {
        raise RelocOverflow("R_X86_64_32S overflow")
      }
      patch_u32(bytes, offset, result.reinterpret_as_uint64())
    }
    R_X86_64_16 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      if result > 0xffffUL {
        raise RelocOverflow("R_X86_64_16 overflow")
      }
      patch_u16(bytes, offset, result)
    }
    R_X86_64_PC8 => {
      let result = sym_value.reinterpret_as_int64() +
        addend -
        pc_offset.reinterpret_as_int64()
      if result < -128L || result > 127L {
        raise RelocOverflow("R_X86_64_PC8 overflow")
      }
      patch_u8(bytes, offset, result.reinterpret_as_uint64())
    }
    R_X86_64_8 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      if result > 0xffUL {
        raise RelocOverflow("R_X86_64_8 overflow")
      }
      patch_u8(bytes, offset, result)
    }
    R_X86_64_PC64 | R_X86_64_GOTPC64 | R_X86_64_GOTPCREL64 => {
      let result = sym_value.reinterpret_as_int64() +
        addend -
        pc_offset.reinterpret_as_int64()
      patch_u64(bytes, offset, result.reinterpret_as_uint64())
    }
    R_X86_64_GLOB_DAT | R_X86_64_JUMP_SLOT | R_X86_64_RELATIVE => {
      let result = sym_value + addend.reinterpret_as_uint64()
      patch_u64(bytes, offset, result)
    }
    _ => raise UnsupportedRelocType(rel_type)
  }
}

///|
fn patch_u64(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 8 > bytes.length() {
    raise BadRelocTarget("patch_u64 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  arr[start + 1] = ((value >> 8) & 0xffUL).to_byte()
  arr[start + 2] = ((value >> 16) & 0xffUL).to_byte()
  arr[start + 3] = ((value >> 24) & 0xffUL).to_byte()
  arr[start + 4] = ((value >> 32) & 0xffUL).to_byte()
  arr[start + 5] = ((value >> 40) & 0xffUL).to_byte()
  arr[start + 6] = ((value >> 48) & 0xffUL).to_byte()
  arr[start + 7] = ((value >> 56) & 0xffUL).to_byte()
  Bytes::from_array(arr)
}

///|
fn patch_u32(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 4 > bytes.length() {
    raise BadRelocTarget("patch_u32 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  arr[start + 1] = ((value >> 8) & 0xffUL).to_byte()
  arr[start + 2] = ((value >> 16) & 0xffUL).to_byte()
  arr[start + 3] = ((value >> 24) & 0xffUL).to_byte()
  Bytes::from_array(arr)
}

///|
fn patch_u16(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 2 > bytes.length() {
    raise BadRelocTarget("patch_u16 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  arr[start + 1] = ((value >> 8) & 0xffUL).to_byte()
  Bytes::from_array(arr)
}

///|
fn patch_u8(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 1 > bytes.length() {
    raise BadRelocTarget("patch_u8 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  Bytes::from_array(arr)
}
