///| AArch64 relocation handlers

///|
const R_AARCH64_NONE : UInt = 0

///|
const R_AARCH64_ABS64 : UInt = 257

///|
const R_AARCH64_ABS32 : UInt = 258

///|
const R_AARCH64_PREL64 : UInt = 260

///|
const R_AARCH64_PREL32 : UInt = 261

///|
pub fn apply_aarch64_reloc(
  bytes : Bytes,
  offset : UInt64,
  rel_type : UInt,
  sym_value : UInt64,
  addend : Int64,
  pc_offset : UInt64,
) -> Bytes raise @ir.RelocError {
  match rel_type {
    R_AARCH64_NONE => bytes
    R_AARCH64_ABS64 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      a64_patch_u64(bytes, offset, result)
    }
    R_AARCH64_ABS32 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      if result > 0xffff_ffffUL {
        raise RelocOverflow("R_AARCH64_ABS32 overflow")
      }
      a64_patch_u32(bytes, offset, result)
    }
    R_AARCH64_PREL64 => {
      let result = sym_value.reinterpret_as_int64() +
        addend -
        pc_offset.reinterpret_as_int64()
      a64_patch_u64(bytes, offset, result.reinterpret_as_uint64())
    }
    R_AARCH64_PREL32 => {
      let result = sym_value.reinterpret_as_int64() +
        addend -
        pc_offset.reinterpret_as_int64()
      if result < -2147483648L || result > 2147483647L {
        raise RelocOverflow("R_AARCH64_PREL32 overflow")
      }
      a64_patch_u32(bytes, offset, result.reinterpret_as_uint64())
    }
    _ => raise UnsupportedRelocType(rel_type)
  }
}

///|
fn a64_patch_u64(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 8 > bytes.length() {
    raise BadRelocTarget("aarch64 patch_u64 out of range")
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
fn a64_patch_u32(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 4 > bytes.length() {
    raise BadRelocTarget("aarch64 patch_u32 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  arr[start + 1] = ((value >> 8) & 0xffUL).to_byte()
  arr[start + 2] = ((value >> 16) & 0xffUL).to_byte()
  arr[start + 3] = ((value >> 24) & 0xffUL).to_byte()
  Bytes::from_array(arr)
}
