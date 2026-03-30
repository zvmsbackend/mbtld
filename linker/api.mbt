///| Linker public API

///|
/// Main entry point for linking
pub fn link(opts : @ir.LinkOptions) -> @ir.LinkArtifact raise @ir.LinkError {
  let ir = build_ir([], opts)
  let ir = @resolve.resolve_symbols(ir, opts) catch {
    UndefinedSymbol(msg) => raise Resolve(UndefinedSymbol(msg))
    MultipleDefinition(msg) => raise Resolve(MultipleDefinition(msg))
    SectionConflict(msg) => raise Resolve(SectionConflict(msg))
  }
  let ir = @resolve.merge_sections(ir, opts) catch {
    UndefinedSymbol(msg) => raise Resolve(UndefinedSymbol(msg))
    MultipleDefinition(msg) => raise Resolve(MultipleDefinition(msg))
    SectionConflict(msg) => raise Resolve(SectionConflict(msg))
  }
  let ir = @reloc.apply_relocations(ir, opts) catch {
    UnsupportedRelocType(t) => raise Reloc(UnsupportedRelocType(t))
    RelocOverflow(msg) => raise Reloc(RelocOverflow(msg))
    BadRelocTarget(msg) => raise Reloc(BadRelocTarget(msg))
  }

  match opts.output_kind {
    Relocatable =>
      @write.write_relocatable(ir, opts) catch {
        LayoutFailure(msg) => raise Write(LayoutFailure(msg))
        InvalidOutputKind(msg) => raise Write(InvalidOutputKind(msg))
        SerializeFailure(msg) => raise Write(SerializeFailure(msg))
      }
    ExecutablePie =>
      @write.write_pie_or_shared(ir, opts) catch {
        LayoutFailure(msg) => raise Write(LayoutFailure(msg))
        InvalidOutputKind(msg) => raise Write(InvalidOutputKind(msg))
        SerializeFailure(msg) => raise Write(SerializeFailure(msg))
      }
    SharedLibrary =>
      @write.write_pie_or_shared(ir, opts) catch {
        LayoutFailure(msg) => raise Write(LayoutFailure(msg))
        InvalidOutputKind(msg) => raise Write(InvalidOutputKind(msg))
        SerializeFailure(msg) => raise Write(SerializeFailure(msg))
      }
    _ => raise Write(InvalidOutputKind("unsupported output kind"))
  }
}
