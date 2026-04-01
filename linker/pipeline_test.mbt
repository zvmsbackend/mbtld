///|
fn p_opts() -> @ir.LinkOptions {
  {
    output: "out.o",
    output_kind: Relocatable,
    entry: "",
    signature: Some("sig-v1"),
    input_files: [],
    dynamic_libs: [],
    dynamic_linker: None,
    strip_symbols: false,
    strip_debug: false,
    no_default_lib: true,
    smart_linking: false,
    linker_heap_no_smart: true,
    linker_heap_size: Some(0UL),
    linker_block_size: Some(0UL),
    linker_block_power: Some(0),
    linker_block_level: Some(0),
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
  assert_true(codes.contains("PIPELINE_LINKER_HEAP_NO_SMART"))
  assert_true(codes.contains("PIPELINE_LINKER_HEAP_SIZE_ZERO"))
  assert_true(codes.contains("PIPELINE_LINKER_BLOCK_SIZE_ZERO"))
  assert_true(codes.contains("PIPELINE_LINKER_BLOCK_POWER_ZERO"))
  assert_true(codes.contains("PIPELINE_LINKER_BLOCK_LEVEL_ZERO"))
  assert_true(codes.contains("PIPELINE_SIGNATURE"))
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

///|
test "run_pipeline rejects dynamic-linker for efi output" {
  let opts = {
    ..p_opts(),
    output_kind: EfiApplication,
    dynamic_linker: Some("/lib64/ld-linux-x86-64.so.2"),
  }

  let mut msg = ""
  try {
    ignore(run_pipeline([], opts))
    abort("expected pipeline error")
  } catch {
    @ir.Cli(@ir.InvalidArgs(m)) => msg = m
    _ => abort("unexpected pipeline error type")
  }

  inspect(msg, content="dynamic-linker is not supported for EFI outputs")
}

///|
test "run_pipeline rejects dynamic libraries for efi output" {
  let opts = {
    ..p_opts(),
    output_kind: EfiRuntimeDriver,
    dynamic_libs: ["libc.so.6"],
  }

  let mut msg = ""
  try {
    ignore(run_pipeline([], opts))
    abort("expected pipeline error")
  } catch {
    @ir.Cli(@ir.InvalidArgs(m)) => msg = m
    _ => abort("unexpected pipeline error type")
  }

  inspect(msg, content="dynamic libraries are not supported for EFI outputs")
}

///|
test "run_pipeline warns when start-address is ignored for relocatable" {
  let opts = { ..p_opts(), start_address: 4096UL }
  let result = run_pipeline([], opts)
  let codes = result.diagnostics.map(d => d.code)
  assert_true(codes.contains("PIPELINE_START_ADDRESS_IGNORED"))
}

///|
test "run_pipeline warns when dynamic-linker is ignored outside executable pie" {
  let opts = {
    ..p_opts(),
    output_kind: SharedLibrary,
    dynamic_linker: Some("/lib64/ld-linux-x86-64.so.2"),
  }
  let result = run_pipeline([], opts)
  let codes = result.diagnostics.map(d => d.code)
  assert_true(codes.contains("PIPELINE_DYNAMIC_LINKER_IGNORED"))
}
