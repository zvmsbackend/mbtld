///| x86_64 relocation handlers

///|
/// x86_64 relocation types
const R_X86_64_NONE : UInt = 0

///|
const R_X86_64_64 : UInt = 1

///|
const R_X86_64_PC32 : UInt = 2

///|
const R_X86_64_GOT32 : UInt = 3

///|
const R_X86_64_PLT32 : UInt = 4

///|
const R_X86_64_GOTPCREL : UInt = 9

///|
const R_X86_64_32 : UInt = 10

///|
const R_X86_64_32S : UInt = 11

///|
/// Apply x86_64 relocation
pub fn apply_x86_64_reloc(
  bytes : Bytes,
  offset : UInt64,
  rel_type : UInt,
  sym_value : UInt64,
  addend : Int64,
  pc_offset : UInt64,
) -> Unit raise @ir.RelocError {
  match rel_type {
    R_X86_64_64 => {
      let result = sym_value + addend.to_uint64()
      patch_u64(bytes, offset, result)
    }
    R_X86_64_PC32 => {
      let result = sym_value + addend.to_uint64() - pc_offset
      patch_u32(bytes, offset, result)
    }
    R_X86_64_32 | R_X86_64_32S => {
      let result = sym_value + addend.to_uint64()
      patch_u32(bytes, offset, result)
    }
    _ => raise UnsupportedRelocType(rel_type)
  }
}

///|
fn patch_u64(bytes : Bytes, offset : UInt64, value : UInt64) -> Unit {
  // TODO: implement byte patching
  ignore((bytes, offset, value))
}

///|
fn patch_u32(bytes : Bytes, offset : UInt64, value : UInt64) -> Unit {
  // TODO: implement byte patching
  ignore((bytes, offset, value))
}
