///| RISC-V 64 relocation handlers

///|
const R_RISCV_NONE : UInt = 0

///|
const R_RISCV_32 : UInt = 1

///|
const R_RISCV_64 : UInt = 2

///|
pub fn apply_riscv64_reloc(
  bytes : Bytes,
  offset : UInt64,
  rel_type : UInt,
  sym_value : UInt64,
  addend : Int64,
  _pc_offset : UInt64,
) -> Bytes raise @ir.RelocError {
  match rel_type {
    R_RISCV_NONE => bytes
    R_RISCV_32 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      if result > 0xffff_ffffUL {
        raise RelocOverflow("R_RISCV_32 overflow")
      }
      rv_patch_u32(bytes, offset, result)
    }
    R_RISCV_64 => {
      let result = sym_value + addend.reinterpret_as_uint64()
      rv_patch_u64(bytes, offset, result)
    }
    _ => raise UnsupportedRelocType(rel_type)
  }
}

///|
fn rv_patch_u64(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 8 > bytes.length() {
    raise BadRelocTarget("riscv64 patch_u64 out of range")
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
fn rv_patch_u32(
  bytes : Bytes,
  offset : UInt64,
  value : UInt64,
) -> Bytes raise @ir.RelocError {
  let start = offset.to_int()
  if start < 0 || start + 4 > bytes.length() {
    raise BadRelocTarget("riscv64 patch_u32 out of range")
  }
  let arr = bytes.to_array()
  arr[start] = (value & 0xffUL).to_byte()
  arr[start + 1] = ((value >> 8) & 0xffUL).to_byte()
  arr[start + 2] = ((value >> 16) & 0xffUL).to_byte()
  arr[start + 3] = ((value >> 24) & 0xffUL).to_byte()
  Bytes::from_array(arr)
}
