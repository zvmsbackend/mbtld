///|
pub struct InputObject {
  path : String
  data : Bytes
} derive(Show)

///|
pub struct ParsedObject {
  path : String
  e_type : UInt16
  e_machine : UInt16
  sections : Array[ParsedSection]
  symbols : Array[ParsedSymbol]
  relocations : Array[ParsedRelocation]
} derive(Show)

///|
pub struct ParsedSection {
  name : String
  name_offset : UInt
  sh_type : UInt
  sh_flags : UInt64
  sh_addr : UInt64
  sh_offset : UInt64
  sh_size : UInt64
  sh_link : UInt
  sh_info : UInt
  sh_addralign : UInt64
  sh_entsize : UInt64
  data : Bytes
} derive(Show)

///|
pub struct ParsedSymbol {
  name : String
  name_offset : UInt
  st_info : Byte
  st_other : Byte
  st_shndx : UInt16
  st_value : UInt64
  st_size : UInt64
} derive(Show)

///|
pub struct ParsedRelocation {
  section_name : String
  r_offset : UInt64
  r_info : UInt64
  r_addend : Int64
  has_addend : Bool
} derive(Show)

///|
/// Archive magic
pub const AR_MAGIC : String = "!<arch>"

///|
pub struct ArchiveMember {
  name : String
  data : Bytes
} derive(Show)
