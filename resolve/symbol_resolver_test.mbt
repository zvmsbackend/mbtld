///|
fn rs_opts(kind : @ir.OutputKind, entry : String) -> @ir.LinkOptions {
  {
    output: "a.out",
    output_kind: kind,
    entry,
    signature: None,
    input_files: [],
    dynamic_libs: [],
    dynamic_linker: None,
    strip_symbols: false,
    strip_debug: false,
    no_default_lib: false,
    smart_linking: false,
    linker_heap_no_smart: false,
    linker_heap_size: None,
    linker_block_size: None,
    linker_block_power: None,
    linker_block_level: None,
    section_align: 4096,
    start_address: 0,
    verbose: false,
  }
}

///|
fn rs_ir(
  sections : Array[@ir.MergedSection],
  symbols : Array[@ir.MergedSymbol],
) -> @ir.LinkIr {
  {
    arch: X86_64,
    bitness: ELF64,
    input_objects: [
      {
        path: "a.o",
        raw: b"A",
        arch: X86_64,
        bitness: ELF64,
        sections: [],
        symbols: [],
        relocs: [],
      },
    ],
    merged_sections: sections,
    merged_symbols: symbols,
    pending_relocs: [],
  }
}

///|
test "resolve_symbols rejects non-executable entry symbol" {
  let ir = rs_ir(
    [{ output_name: ".data", output_index: 0, align: 1UL, bytes: b"\x01" }],
    [
      {
        name: "main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Object,
        vis: Default,
      },
    ],
  )

  let mut msg = ""
  try {
    ignore(resolve_symbols(ir, rs_opts(ExecutablePie, "main")))
    abort("expected resolve error")
  } catch {
    SectionConflict(m) => msg = m
    _ => abort("unexpected resolve error type")
  }
  inspect(msg, content="entry symbol is not executable: main")
}

///|
test "resolve_symbols rejects undefined entry symbol definition" {
  let ir = rs_ir(
    [{ output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90" }],
    [
      {
        name: "main",
        output_sec: -1,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  )

  let mut msg = ""
  try {
    ignore(resolve_symbols(ir, rs_opts(ExecutablePie, "main")))
    abort("expected resolve error")
  } catch {
    UndefinedSymbol(m) => msg = m
    _ => abort("unexpected resolve error type")
  }
  inspect(msg, content="main")
}

///|
test "resolve_symbols accepts executable entry symbol" {
  let ir = rs_ir(
    [{ output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90" }],
    [
      {
        name: "main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  )

  let out = resolve_symbols(ir, rs_opts(ExecutablePie, "main"))
  inspect(out.merged_symbols.length(), content="1")
}

///|
test "to_structured_diagnostic maps undefined symbol to stable code" {
  let diag = to_structured_diagnostic(UndefinedSymbol("foo"))
  inspect(diag.code, content="RESOLVE_UNDEFINED_SYMBOL")
  inspect(diag.message, content="undefined symbol: foo")
  inspect(diag.symbol, content="Some(\"foo\")")
}

///|
test "to_structured_diagnostic keeps explicit symbol override" {
  let diag = to_structured_diagnostic(
    MultipleDefinition("foo"),
    file="a.o",
    symbol="bar",
  )
  inspect(diag.code, content="RESOLVE_MULTIPLE_DEFINITION")
  inspect(diag.file, content="Some(\"a.o\")")
  inspect(diag.symbol, content="Some(\"bar\")")
}
