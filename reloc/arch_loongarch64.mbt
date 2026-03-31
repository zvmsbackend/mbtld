///| LoongArch64 relocation handlers

///|
const R_LARCH_NONE : UInt = 0

///|
const R_LARCH_32 : UInt = 1

///|
const R_LARCH_64 : UInt = 3

///|
pub fn apply_loongarch64_reloc(
  bytes : Bytes,
  offset : UInt64,
  rel_type : UInt,
  sym_value : UInt64,
  addend : Int64,
  _pc_offset : UInt64,
) -> Bytes raise @ir.RelocError {
  match rel_type {
    R_LARCH_NONE => bytes
    R_LARCH_32 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      if result > 0xffff_ffffUL {
        raise RelocOverflow("R_LARCH_32 overflow")
      }
      la_patch_u32(bytes, offset, result)
    }
    R_LARCH_64 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      la_patch_u64(bytes, offset, result)
    }
    _ => raise UnsupportedRelocType(rel_type)
  }
}

///|
fn la_patch_u64(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 8 > bytes.length() {
    raise BadRelocTarget("loongarch64 patch_u64 out of range")
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
fn la_patch_u32(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 4 > bytes.length() {
    raise BadRelocTarget("loongarch64 patch_u32 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  arr[start + 1] = ((value >> 8) & 0xffUL).to_byte()
  arr[start + 2] = ((value >> 16) & 0xffUL).to_byte()
  arr[start + 3] = ((value >> 24) & 0xffUL).to_byte()
  Bytes::from_array(arr)
}
