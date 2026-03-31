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
