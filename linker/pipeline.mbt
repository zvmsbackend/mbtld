///| Linker pipeline orchestration

///|
/// Pipeline stage result
pub struct PipelineResult {
  ir : @ir.LinkIr
  diagnostics : Array[Diagnostic]
} derive(Show)

///|
/// Diagnostic message
pub struct Diagnostic {
  level : DiagLevel
  code : String
  message : String
  file : String?
  section : String?
  symbol : String?
} derive(Show)

///|
/// Diagnostic level
enum DiagLevel {
  Error
  Warning
  Info
} derive(Show, Eq)

///|
/// Run linking pipeline
pub fn run_pipeline(
  inputs : Array[@ir.InputObject],
  opts : @ir.LinkOptions,
) -> PipelineResult raise @ir.LinkError {
  let diagnostics : Array[Diagnostic] = []
  if opts.verbose {
    diagnostics.push({
      level: Info,
      code: "PIPELINE_INFO",
      message: "running linker pipeline",
      file: None,
      section: None,
      symbol: None,
    })
  }
  if inputs.length() == 0 {
    diagnostics.push({
      level: Error,
      code: "PIPELINE_EMPTY_INPUT",
      message: "no input objects supplied",
      file: None,
      section: None,
      symbol: None,
    })
  }
  if opts.no_default_lib {
    diagnostics.push({
      level: Warning,
      code: "PIPELINE_NO_DEFAULT_LIB",
      message: "default libraries are disabled",
      file: None,
      section: None,
      symbol: None,
    })
  }

  let ir = build_ir(inputs, opts)
  diagnostics.push({
    level: Info,
    code: "PIPELINE_INPUTS",
    message: "inputs=\{inputs.length()}",
    file: None,
    section: None,
    symbol: None,
  })
  diagnostics.push({
    level: Info,
    code: "PIPELINE_MERGED_SECTIONS",
    message: "merged_sections=\{ir.merged_sections.length()}",
    file: None,
    section: None,
    symbol: None,
  })
  diagnostics.push({
    level: Info,
    code: "PIPELINE_MERGED_SYMBOLS",
    message: "merged_symbols=\{ir.merged_symbols.length()}",
    file: None,
    section: None,
    symbol: None,
  })
  diagnostics.push({
    level: Info,
    code: "PIPELINE_PENDING_RELOCS",
    message: "pending_relocs=\{ir.pending_relocs.length()}",
    file: None,
    section: None,
    symbol: None,
  })

  if ir.merged_sections.length() == 0 {
    diagnostics.push({
      level: Warning,
      code: "PIPELINE_NO_SECTIONS",
      message: "no merged sections were produced",
      file: None,
      section: None,
      symbol: None,
    })
  }

  let mut unresolved_symbols = 0
  for sym in ir.merged_symbols {
    if sym.output_sec < 0 {
      unresolved_symbols += 1
    }
  }
  if unresolved_symbols > 0 {
    diagnostics.push({
      level: Warning,
      code: "PIPELINE_UNRESOLVED_SYMBOLS",
      message: "unresolved_symbols=\{unresolved_symbols}",
      file: None,
      section: None,
      symbol: None,
    })
  }

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

  { ir, diagnostics }
}
