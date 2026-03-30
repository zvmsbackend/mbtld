///|
/// Symbol binding values
pub const STB_LOCAL : Byte = 0

///|
pub const STB_GLOBAL : Byte = 1

///|
pub const STB_WEAK : Byte = 2

///|
/// Symbol type values
pub const STT_NOTYPE : Byte = 0

///|
pub const STT_OBJECT : Byte = 1

///|
pub const STT_FUNC : Byte = 2

///|
pub const STT_SECTION : Byte = 3

///|
pub const STT_FILE : Byte = 4

///|
pub const STT_COMMON : Byte = 5

///|
pub const STT_TLS : Byte = 6

///|
/// Symbol visibility values
pub const STV_DEFAULT : Byte = 0

///|
pub const STV_INTERNAL : Byte = 1

///|
pub const STV_HIDDEN : Byte = 2

///|
pub const STV_PROTECTED : Byte = 3

///|
/// Special symbol indices
pub const SHN_UNDEF : UInt16 = 0

///|
pub const SHN_ABS : UInt16 = 0xfff1

///|
pub const SHN_COMMON : UInt16 = 0xfff2

///|
/// ELF64 symbol
pub struct Elf64Sym {
  st_name : UInt
  st_info : Byte
  st_other : Byte
  st_shndx : UInt16
  st_value : UInt64
  st_size : UInt64
} derive(Show)

///|
pub fn Elf64Sym::binding(self : Elf64Sym) -> Byte {
  self.st_info >> 4
}

///|
pub fn Elf64Sym::sym_type(self : Elf64Sym) -> Byte {
  self.st_info & 0xf
}

///|
pub fn Elf64Sym::visibility(self : Elf64Sym) -> Byte {
  self.st_other & 0xf
}

///|
pub fn Elf64Sym::is_defined(self : Elf64Sym) -> Bool {
  self.st_shndx != SHN_UNDEF
}

///|
pub fn Elf64Sym::is_undefined(self : Elf64Sym) -> Bool {
  self.st_shndx == SHN_UNDEF
}
