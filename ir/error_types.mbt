///|
/// CLI error subtypes
pub(all) suberror CliError {
  InvalidArgs(String)
  MissingValue(String)
  UnsupportedFlag(String)
}

///|
/// ELF parsing error subtypes
pub(all) suberror ElfError {
  BadSignature(String)
  UnsupportedClass(String)
  UnsupportedMachine(String)
  InvalidObjectType(String)
  CorruptArchive(String)
  TruncatedFile(String)
  InvalidSection(String)
  InvalidSymbol(String)
  InvalidRelocation(String)
}

///|
/// Symbol resolution error subtypes
pub(all) suberror ResolveError {
  UndefinedSymbol(String)
  MultipleDefinition(String)
  SectionConflict(String)
}

///|
/// Relocation error subtypes
pub(all) suberror RelocError {
  UnsupportedRelocType(UInt)
  RelocOverflow(String)
  BadRelocTarget(String)
}

///|
/// Write error subtypes
pub(all) suberror WriteError {
  LayoutFailure(String)
  InvalidOutputKind(String)
  SerializeFailure(String)
}

///|
/// Top-level link error
pub(all) suberror LinkError {
  Cli(CliError)
  Elf(ElfError)
  Resolve(ResolveError)
  Reloc(RelocError)
  Write(WriteError)
}
