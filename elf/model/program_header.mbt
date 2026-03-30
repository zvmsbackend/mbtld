///|
/// ELF program header type values
pub const PT_NULL : UInt = 0

///|
pub const PT_LOAD : UInt = 1

///|
pub const PT_DYNAMIC : UInt = 2

///|
pub const PT_INTERP : UInt = 3

///|
pub const PT_NOTE : UInt = 4

///|
pub const PT_SHLIB : UInt = 5

///|
pub const PT_PHDR : UInt = 6

///|
/// Program header flags
pub const PF_X : UInt = 0x1

///|
pub const PF_W : UInt = 0x2

///|
pub const PF_R : UInt = 0x4

///|
/// ELF64 program header
pub struct Elf64Phdr {
  p_type : UInt
  p_flags : UInt
  p_offset : UInt64
  p_vaddr : UInt64
  p_paddr : UInt64
  p_filesz : UInt64
  p_memsz : UInt64
  p_align : UInt64
} derive(Show)
