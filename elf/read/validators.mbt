///|
suberror ElfError {
  BadSignature(String)
  UnsupportedClass(String)
  UnsupportedMachine(String)
  InvalidObjectType(String)
  CorruptArchive(String)
  TruncatedFile(String)
  InvalidSection(String)
  InvalidSymbol(String)
  InvalidRelocation(String)
} derive(Show)

///|
/// Check if bytes start with ELF magic
pub fn is_elf_magic(data : BytesView) -> Bool {
  data is [0x7F, 'E', 'L', 'F', ..]
}
