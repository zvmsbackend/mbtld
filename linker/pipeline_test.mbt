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
