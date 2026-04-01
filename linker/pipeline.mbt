///| Linker pipeline orchestration

///|
/// Pipeline stage result
pub struct PipelineResult {
  ir : @ir.LinkIr
  diagnostics : Array[@resolve.Diagnostic]
} derive(Show)

///|
enum DiagLevel {
  Error
  Warning
  Info
} derive(Show, Eq)

///|
fn pipeline_diag(
  level : DiagLevel,
  code : String,
  message : String,
  file? : String,
  section? : String,
  symbol? : String,
) -> @resolve.Diagnostic {
  match level {
    Error => @resolve.error_at(code, message, file?=file, section?=section, symbol?=symbol)
    Warning =>
      @resolve.warning_at(
        code,
        message,
        file?=file,
        section?=section,
        symbol?=symbol,
      )
    Info =>
      @resolve.info_at(
        code,
        message,
        file?=file,
        section?=section,
        symbol?=symbol,
      )
  }
}

///|
fn first_input_file(inputs : Array[@ir.InputObject]) -> String? {
  inputs.get(0).map(inp => inp.path)
}

///|
fn pipeline_is_exec_section(name : String) -> Bool {
  name == ".text" ||
  name == ".init" ||
  name == ".fini" ||
  name.has_prefix(".text.")
}

///|
fn pipeline_is_efi_output(kind : @ir.OutputKind) -> Bool {
  kind is (@ir.EfiApplication | @ir.EfiBootDriver | @ir.EfiRuntimeDriver)
}

///|
fn pipeline_validate_option_matrix(
  opts : @ir.LinkOptions,
  diagnostics : Array[@resolve.Diagnostic],
) -> Unit raise @ir.LinkError {
  if pipeline_is_efi_output(opts.output_kind) {
    if opts.dynamic_linker is Some(ld) && ld != "" {
      raise Cli(
        @ir.InvalidArgs("dynamic-linker is not supported for EFI outputs"),
      )
    }
    if opts.dynamic_libs.length() > 0 {
      raise Cli(
        @ir.InvalidArgs(
          "dynamic libraries are not supported for EFI outputs",
        ),
      )
    }
  }

  if opts.output_kind is @ir.Relocatable && opts.start_address != 0UL {
    diagnostics.push(
      pipeline_diag(
        Warning,
        "PIPELINE_START_ADDRESS_IGNORED",
        "start-address is ignored for relocatable output",
        file="<options>",
      ),
    )
  }

  if !(opts.output_kind is @ir.ExecutablePie) {
    if opts.dynamic_linker is Some(ld) && ld != "" {
      diagnostics.push(
        pipeline_diag(
          Warning,
          "PIPELINE_DYNAMIC_LINKER_IGNORED",
          "dynamic-linker is only used for executable PIE output",
          file="<options>",
        ),
      )
    }
  }
}

///|
fn pipeline_find_fallback_entry(ir : @ir.LinkIr) -> String? {
  let candidates = ["_start", "main"]
  for cand in candidates {
    for sym in ir.merged_symbols {
      if sym.name != cand {
        continue
      }
      if sym.output_sec < 0 || sym.output_sec >= ir.merged_sections.length() {
        continue
      }
      let sec_name = ir.merged_sections[sym.output_sec].output_name
      if sym.ty is @ir.Func || pipeline_is_exec_section(sec_name) {
        return Some(cand)
      }
    }
  }
  None
}

///|
/// Run linking pipeline
pub fn run_pipeline(
  inputs : Array[@ir.InputObject],
  opts : @ir.LinkOptions,
) -> PipelineResult raise @ir.LinkError {
  let diagnostics : Array[@resolve.Diagnostic] = []
  let first_file = first_input_file(inputs)

  if opts.verbose {
    diagnostics.push(
      pipeline_diag(
        Info,
        "PIPELINE_INFO",
        "running linker pipeline",
        file?=first_file,
      ),
    )
  }
  if inputs.length() == 0 {
    diagnostics.push(
      pipeline_diag(
        Error,
        "PIPELINE_EMPTY_INPUT",
        "no input objects supplied",
        file="<cli>",
      ),
    )
  }
  if opts.no_default_lib {
    diagnostics.push(
      pipeline_diag(
        Warning,
        "PIPELINE_NO_DEFAULT_LIB",
        "default libraries are disabled",
        file="<options>",
      ),
    )
  }
  if opts.linker_heap_no_smart {
    diagnostics.push(
      pipeline_diag(
        Info,
        "PIPELINE_LINKER_HEAP_NO_SMART",
        "linker heap smart adjustment is disabled",
        file="<options>",
      ),
    )
  }
  if opts.linker_heap_size is Some(size) {
    if size == 0UL {
      diagnostics.push(
        pipeline_diag(
          Warning,
          "PIPELINE_LINKER_HEAP_SIZE_ZERO",
          "linker heap size is zero",
          file="<options>",
        ),
      )
    } else {
      diagnostics.push(
        pipeline_diag(
          Info,
          "PIPELINE_LINKER_HEAP_SIZE",
          "linker_heap_size=\{size}",
          file="<options>",
        ),
      )
    }
  }
  if opts.linker_block_size is Some(size) {
    if size == 0UL {
      diagnostics.push(
        pipeline_diag(
          Warning,
          "PIPELINE_LINKER_BLOCK_SIZE_ZERO",
          "linker block size is zero",
          file="<options>",
        ),
      )
    } else {
      diagnostics.push(
        pipeline_diag(
          Info,
          "PIPELINE_LINKER_BLOCK_SIZE",
          "linker_block_size=\{size}",
          file="<options>",
        ),
      )
    }
  }
  if opts.linker_block_power is Some(power) {
    if power == 0 {
      diagnostics.push(
        pipeline_diag(
          Warning,
          "PIPELINE_LINKER_BLOCK_POWER_ZERO",
          "linker block power is zero",
          file="<options>",
        ),
      )
    } else {
      diagnostics.push(
        pipeline_diag(
          Info,
          "PIPELINE_LINKER_BLOCK_POWER",
          "linker_block_power=\{power}",
          file="<options>",
        ),
      )
    }
  }
  if opts.linker_block_level is Some(level) {
    if level == 0 {
      diagnostics.push(
        pipeline_diag(
          Warning,
          "PIPELINE_LINKER_BLOCK_LEVEL_ZERO",
          "linker block level is zero",
          file="<options>",
        ),
      )
    } else {
      diagnostics.push(
        pipeline_diag(
          Info,
          "PIPELINE_LINKER_BLOCK_LEVEL",
          "linker_block_level=\{level}",
          file="<options>",
        ),
      )
    }
  }
  if opts.signature is Some(sig) {
    diagnostics.push(
      pipeline_diag(
        Info,
        "PIPELINE_SIGNATURE",
        "signature=\{sig}",
        file="<options>",
      ),
    )
  }

  pipeline_validate_option_matrix(opts, diagnostics)

  let ir = build_ir(inputs, opts)
  diagnostics.push(
    pipeline_diag(
      Info,
      "PIPELINE_INPUTS",
      "inputs=\{inputs.length()}",
      file?=first_file,
    ),
  )
  diagnostics.push(
    pipeline_diag(
      Info,
      "PIPELINE_MERGED_SECTIONS",
      "merged_sections=\{ir.merged_sections.length()}",
      file?=first_file,
    ),
  )
  diagnostics.push(
    pipeline_diag(
      Info,
      "PIPELINE_MERGED_SYMBOLS",
      "merged_symbols=\{ir.merged_symbols.length()}",
      file?=first_file,
    ),
  )
  diagnostics.push(
    pipeline_diag(
      Info,
      "PIPELINE_PENDING_RELOCS",
      "pending_relocs=\{ir.pending_relocs.length()}",
      file?=first_file,
    ),
  )

  if ir.merged_sections.length() == 0 {
    diagnostics.push(
      pipeline_diag(
        Warning,
        "PIPELINE_NO_SECTIONS",
        "no merged sections were produced",
        file?=first_file,
      ),
    )
  }

  let mut unresolved_symbols = 0
  for sym in ir.merged_symbols {
    if sym.output_sec < 0 {
      unresolved_symbols += 1
      diagnostics.push(
        pipeline_diag(
          Warning,
          "PIPELINE_UNRESOLVED_SYMBOL",
          "unresolved symbol",
          file?=first_file,
        ),
      )
    }
  }
  if unresolved_symbols > 0 {
    diagnostics.push(
      pipeline_diag(
        Warning,
        "PIPELINE_UNRESOLVED_SYMBOLS",
        "unresolved_symbols=\{unresolved_symbols}",
        file?=first_file,
      ),
    )
  }

  if opts.output_kind is @ir.ExecutablePie && opts.entry == "" {
    match pipeline_find_fallback_entry(ir) {
      Some(sym_name) =>
        diagnostics.push(
          pipeline_diag(
            Info,
            "PIPELINE_ENTRY_FALLBACK",
            "using fallback entry symbol: \{sym_name}",
            file?=first_file,
            symbol=sym_name,
          ),
        )
      None =>
        diagnostics.push(
          pipeline_diag(
            Warning,
            "PIPELINE_ENTRY_MISSING",
            "no executable fallback entry symbol found (_start/main)",
            file?=first_file,
          ),
        )
    }
  }

  let ir = @resolve.resolve_symbols(ir, opts) catch { e => raise Resolve(e) }
  let ir = @resolve.merge_sections(ir, opts) catch { e => raise Resolve(e) }
  let ir = @reloc.apply_relocations(ir, opts) catch { e => raise Reloc(e) }

  { ir, diagnostics }
}
