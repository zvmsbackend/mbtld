///|
fn mk_opts(inputs : Array[String]) -> @ir.LinkOptions {
  {
    output: "out.o",
    output_kind: Relocatable,
    entry: "",
    input_files: inputs,
    dynamic_libs: [],
    dynamic_linker: None,
    strip_symbols: false,
    strip_debug: false,
    no_default_lib: false,
    smart_linking: false,
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
