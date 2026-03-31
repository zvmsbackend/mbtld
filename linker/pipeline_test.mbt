///|
fn p_opts() -> @ir.LinkOptions {
  {
    output: "out.o",
    output_kind: Relocatable,
    entry: "",
    input_files: [],
    dynamic_libs: [],
    dynamic_linker: None,
    strip_symbols: false,
    strip_debug: false,
    no_default_lib: true,
    smart_linking: false,
    section_align: 4096,
    start_address: 0,
    verbose: true,
  }
}

///|
fn p_opts_exe() -> @ir.LinkOptions {
  {
    ..p_opts(),
    output_kind: ExecutablePie,
    no_default_lib: false,
    verbose: false,
  }
}

///|
fn p_mk_input(
  sec_name : String,
  sym_name : String,
  sym_ty : @ir.SymbolType,
) -> @ir.InputObject {
  {
    path: "a.o",
    raw: b"A",
    arch: X86_64,
    bitness: ELF64,
    sections: [
      {
        name: sec_name,
        name_hash: sec_name.hash().to_uint64(),
        ty: 1,
        flags: 0UL,
        align: 1UL,
        data: b"\x90",
        info: 0,
        link: 0,
      },
    ],
    symbols: [
      {
        name: sym_name,
        name_hash: sym_name.hash().to_uint64(),
        binding: Global,
        ty: sym_ty,
        vis: Default,
        sec_index: 0,
        value: 0UL,
        size: 0UL,
      },
    ],
    relocs: [],
  }
}

///|
test "run_pipeline emits baseline diagnostics" {
  let result = run_pipeline([], p_opts())

  let codes = result.diagnostics.map(d => d.code)
  assert_true(codes.contains("PIPELINE_INFO"))
  assert_true(codes.contains("PIPELINE_EMPTY_INPUT"))
  assert_true(codes.contains("PIPELINE_NO_DEFAULT_LIB"))
  assert_true(codes.contains("PIPELINE_INPUTS"))
  assert_true(codes.contains("PIPELINE_MERGED_SECTIONS"))
  assert_true(codes.contains("PIPELINE_MERGED_SYMBOLS"))
  assert_true(codes.contains("PIPELINE_PENDING_RELOCS"))
  assert_true(codes.contains("PIPELINE_NO_SECTIONS"))
}

///|
test "run_pipeline reports executable pie fallback entry" {
  let result = run_pipeline([p_mk_input(".text", "_start", Func)], p_opts_exe())
  let codes = result.diagnostics.map(d => d.code)
  assert_true(codes.contains("PIPELINE_ENTRY_FALLBACK"))
}

///|
test "run_pipeline warns when executable pie fallback entry missing" {
  let result = run_pipeline(
    [p_mk_input(".data", "value", Object)],
    p_opts_exe(),
  )
  let codes = result.diagnostics.map(d => d.code)
  assert_true(codes.contains("PIPELINE_ENTRY_MISSING"))
}
