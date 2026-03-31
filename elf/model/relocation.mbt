///|
/// Relocation types for x86_64
pub const R_X86_64_NONE : UInt = 0

///|
pub const R_X86_64_64 : UInt = 1

///|
pub const R_X86_64_PC32 : UInt = 2

///|
pub const R_X86_64_GOT32 : UInt = 3

///|
pub const R_X86_64_PLT32 : UInt = 4

///|
pub const R_X86_64_COPY : UInt = 5

///|
pub const R_X86_64_GLOB_DAT : UInt = 6

///|
pub const R_X86_64_JUMP_SLOT : UInt = 7

///|
pub const R_X86_64_RELATIVE : UInt = 8

///|
pub const R_X86_64_GOTPCREL : UInt = 9

///|
pub const R_X86_64_32 : UInt = 10

///|
pub const R_X86_64_32S : UInt = 11

///|
pub const R_X86_64_16 : UInt = 12

///|
pub const R_X86_64_PC8 : UInt = 14

///|
pub const R_X86_64_8 : UInt = 15

///|
pub const R_X86_64_PC64 : UInt = 24

///|
pub const R_X86_64_GOTPC64 : UInt = 26

///|
pub const R_X86_64_GOTPCREL64 : UInt = 28

///|
pub const R_X86_64_64_32 : UInt = 38

///|
/// Relocation types for AArch64
pub const R_AARCH64_NONE : UInt = 0

///|
pub const R_AARCH64_ABS64 : UInt = 257

///|
pub const R_AARCH64_ABS32 : UInt = 258

///|
pub const R_AARCH64_ABS16 : UInt = 259

///|
pub const R_AARCH64_PREL64 : UInt = 260

///|
pub const R_AARCH64_PREL32 : UInt = 261

///|
pub const R_AARCH64_PREL16 : UInt = 262

///|
/// Relocation types for RISC-V
pub const R_RISCV_NONE : UInt = 0

///|
pub const R_RISCV_32 : UInt = 1

///|
pub const R_RISCV_64 : UInt = 2

///|
/// Relocation types for LoongArch
pub const R_LARCH_NONE : UInt = 0

///|
pub const R_LARCH_64 : UInt = 3

///|
pub const R_LARCH_32 : UInt = 1

///|
/// ELF64 relocation entry (without addend)
pub struct Elf64Rel {
  r_offset : UInt64
  r_info : UInt64
} derive(Show, Default)

///|
/// ELF64 relocation entry (with addend)
pub struct Elf64Rela {
  r_offset : UInt64
  r_info : UInt64
  r_addend : Int64
} derive(Show, Default)

///|
pub fn Elf64Rel::sym_index(self : Elf64Rel) -> UInt {
  (self.r_info >> 32).to_uint()
}

///|
pub fn Elf64Rel::rel_type(self : Elf64Rel) -> UInt {
  (self.r_info & 0xffffffff).to_uint()
}

///|
pub fn Elf64Rela::sym_index(self : Elf64Rela) -> UInt {
  (self.r_info >> 32).to_uint()
}

///|
pub fn Elf64Rela::rel_type(self : Elf64Rela) -> UInt {
  (self.r_info & 0xffffffff).to_uint()
}
