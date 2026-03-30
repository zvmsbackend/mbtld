///|
/// ELF identification indices
pub const EI_MAG0 : Int = 0

///|
pub const EI_MAG1 : Int = 1

///|
pub const EI_MAG2 : Int = 2

///|
pub const EI_MAG3 : Int = 3

///|
pub const EI_CLASS : Int = 4

///|
pub const EI_DATA : Int = 5

///|
pub const EI_VERSION : Int = 6

///|
pub const EI_OSABI : Int = 7

///|
pub const EI_ABIVERSION : Int = 8

///|
pub const EI_NIDENT : Int = 16

///|
/// ELF magic bytes
pub const ELFMAG0 : Byte = 0x7f

///|
pub const ELFMAG1 : Byte = 'E'

///|
pub const ELFMAG2 : Byte = 'L'

///|
pub const ELFMAG3 : Byte = 'F'

///|
/// ELF class values
pub const ELFCLASS32 : Byte = 1

///|
pub const ELFCLASS64 : Byte = 2

///|
/// ELF data encoding values
pub const ELFDATA2LSB : Byte = 1

///|
pub const ELFDATA2MSB : Byte = 2

///|
/// ELF file type values
pub const ET_NONE : UInt16 = 0

///|
pub const ET_REL : UInt16 = 1

///|
pub const ET_EXEC : UInt16 = 2

///|
pub const ET_DYN : UInt16 = 3

///|
pub const ET_CORE : UInt16 = 4

///|
/// ELF machine type values
pub const EM_NONE : UInt16 = 0

///|
pub const EM_386 : UInt16 = 3

///|
pub const EM_X86_64 : UInt16 = 62

///|
pub const EM_AARCH64 : UInt16 = 183

///|
pub const EM_RISCV : UInt16 = 243

///|
pub const EM_LOONGARCH : UInt16 = 258

///|
/// ELF64 header
pub(all) struct Elf64Ehdr {
  e_ident : Bytes
  e_type : UInt16
  e_machine : UInt16
  e_version : UInt
  e_entry : UInt64
  e_phoff : UInt64
  e_shoff : UInt64
  e_flags : UInt
  e_ehsize : UInt16
  e_phentsize : UInt16
  e_phnum : UInt16
  e_shentsize : UInt16
  e_shnum : UInt16
  e_shstrndx : UInt16
} derive(Show)

///|
/// ELF64 section header
pub struct Elf64Shdr {
  sh_name : UInt
  sh_type : UInt
  sh_flags : UInt64
  sh_addr : UInt64
  sh_offset : UInt64
  sh_size : UInt64
  sh_link : UInt
  sh_info : UInt
  sh_addralign : UInt64
  sh_entsize : UInt64
} derive(Show)

///|
/// Section header type values
pub const SHT_NULL : UInt = 0

///|
pub const SHT_PROGBITS : UInt = 1

///|
pub const SHT_SYMTAB : UInt = 2

///|
pub const SHT_STRTAB : UInt = 3

///|
pub const SHT_RELA : UInt = 4

///|
pub const SHT_HASH : UInt = 5

///|
pub const SHT_DYNAMIC : UInt = 6

///|
pub const SHT_NOTE : UInt = 7

///|
pub const SHT_NOBITS : UInt = 8

///|
pub const SHT_REL : UInt = 9

///|
pub const SHT_SHLIB : UInt = 10

///|
pub const SHT_DYNSYM : UInt = 11

///|
pub const SHT_INIT_ARRAY : UInt = 14

///|
pub const SHT_FINI_ARRAY : UInt = 15

///|
pub const SHT_PREINIT_ARRAY : UInt = 16

///|
pub const SHT_GROUP : UInt = 17

///|
pub const SHT_SYMTAB_SHNDX : UInt = 18

///|
/// Section header flags
pub const SHF_WRITE : UInt64 = 0x1

///|
pub const SHF_ALLOC : UInt64 = 0x2

///|
pub const SHF_EXECINSTR : UInt64 = 0x4

///|
pub const SHF_MERGE : UInt64 = 0x10

///|
pub const SHF_STRINGS : UInt64 = 0x20

///|
pub const SHF_INFO_LINK : UInt64 = 0x40

///|
pub const SHF_LINK_ORDER : UInt64 = 0x80

///|
pub const SHF_OS_NONCONFORMING : UInt64 = 0x100

///|
pub const SHF_GROUP : UInt64 = 0x200

///|
pub const SHF_TLS : UInt64 = 0x400

///|
/// ELF64 structure sizes
pub const ELF64_EHDR_SIZE : Int = 64

///|
pub const ELF64_SHDR_SIZE : Int = 64

///|
pub const ELF64_PHDR_SIZE : Int = 56

///|
pub const ELF64_SYM_SIZE : Int = 24

///|
pub const ELF64_REL_SIZE : Int = 16

///|
pub const ELF64_RELA_SIZE : Int = 24
