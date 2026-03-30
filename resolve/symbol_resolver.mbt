///| Resolve symbols and merge sections

///|
/// Resolve symbols in IR
pub fn resolve_symbols(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkIr raise @ir.ResolveError {
  ir
}

///|
/// Merge sections in IR
pub fn merge_sections(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkIr raise @ir.ResolveError {
  ir
}

///|
/// Convert error to diagnostic message
pub fn to_diagnostic(err : @ir.ResolveError) -> String {
  match err {
    UndefinedSymbol(name) => "undefined symbol: \{name}"
    MultipleDefinition(name) => "multiple definition: \{name}"
    SectionConflict(msg) => "section conflict: \{msg}"
  }
}
