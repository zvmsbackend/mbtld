///| Resolve symbols and merge sections

///|
/// Resolve symbols in IR
pub fn resolve_symbols(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkIr raise @ir.ResolveError {
  let symbol_count = ir.merged_symbols.length()
  for reloc in ir.pending_relocs {
    if reloc.target_sym < 0 || reloc.target_sym >= symbol_count {
      raise UndefinedSymbol("relocation target index \{reloc.target_sym}")
    }
  }

  if opts.output_kind != @ir.Relocatable && opts.entry != "" {
    let found = ir.merged_symbols.search_by(sym => sym.name == opts.entry)
    if found is None {
      raise UndefinedSymbol(opts.entry)
    }
  }

  if opts.smart_linking && ir.merged_symbols.length() == 0 {
    raise SectionConflict("smart-linking requires at least one merged symbol")
  }

  ir
}

///|
/// Merge sections in IR
pub fn merge_sections(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkIr raise @ir.ResolveError {
  if opts.section_align == 0 {
    raise SectionConflict("section alignment cannot be zero")
  }

  let seen : Array[Int] = []
  for sec in ir.merged_sections {
    if seen.contains(sec.output_index) {
      raise SectionConflict(
        "duplicate output section index \{sec.output_index}",
      )
    }
    seen.push(sec.output_index)
  }

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
