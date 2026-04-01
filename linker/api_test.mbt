///|
fn mk_opts(inputs : Array[String]) -> @ir.LinkOptions {
  {
    output: "out.o",
    output_kind: Relocatable,
    entry: "",
    signature: None,
    input_files: inputs,
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
test "link rejects empty input list" {
  let mut msg = ""
  try {
    link(mk_opts([])) |> ignore
    abort("expected error")
  } catch {
    @ir.Cli(@ir.InvalidArgs(m)) => msg = m
    _ => abort("unexpected error type")
  }
  inspect(msg, content="no input files")
}

///|
test "link preserves detailed ELF parse error" {
  let path = "/tmp/mbtld_invalid_object_test.o"
  @fs.write_bytes_to_file(path, b"not an elf") |> ignore

  let mut msg = ""
  try {
    link(mk_opts([path])) |> ignore
    abort("expected parse failure")
  } catch {
    @ir.Elf(@ir.InvalidObjectType(m)) => msg = m
    _ => abort("unexpected error type")
  }

  inspect(
    msg,
    content="failed to parse object /tmp/mbtld_invalid_object_test.o",
  )
}
