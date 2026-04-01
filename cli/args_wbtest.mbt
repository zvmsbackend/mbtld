///|
test "parse_args rejects missing input-path" {
  let mut ok = false
  try {
    [
      "mbtld", "-o", "out.o", "--input-path", "/tmp/mbtld/path/that/does/not/exist",
    ]
    |> parse_args
    |> ignore
    abort("expected parse error")
  } catch {
    InvalidArgs(_) => ok = true
    _ => abort("unexpected error type")
  }
  assert_true(ok)
}

///|
test "run_cli handles version without parsing full args" {
  inspect(run_cli(["mbtld", "--version"]), content="0")
}

///|
test "parse_args parses linker tuning and signature options" {
  let opts = parse_args([
    "mbtld", "-o", "out.so", "--shared", "--signature", "sig-v2", "--linker-heap-no-smart",
    "--linker-heap-size", "1024", "--linker-block-size", "256", "--linker-block-power",
    "4", "--linker-block-level", "7",
  ])

  inspect(opts.signature, content="Some(\"sig-v2\")")
  inspect(opts.linker_heap_no_smart, content="true")
  inspect(opts.linker_heap_size, content="Some(1024)")
  inspect(opts.linker_block_size, content="Some(256)")
  inspect(opts.linker_block_power, content="Some(4)")
  inspect(opts.linker_block_level, content="Some(7)")
}

///|
test "parse_args accepts pasld alias flags for strip options" {
  let opts = parse_args([
    "mbtld", "-o", "out.so", "--dynamic-library", "--no-symbol-table", "--no-debug-frame",
  ])

  inspect(opts.output_kind, content="SharedLibrary")
  inspect(opts.strip_symbols, content="true")
  inspect(opts.strip_debug, content="true")
}

///|
test "parse_args accepts pasld alias option for dynamic linker path" {
  let opts = parse_args([
    "mbtld", "-o", "a.out", "--executable", "--dynamic-linker-path", "/lib64/ld.so",
  ])

  inspect(opts.dynamic_linker, content="Some(\"/lib64/ld.so\")")
}

///|
test "parse_args accepts pasld no-default-library alias" {
  let opts = parse_args([
    "mbtld", "-o", "a.out", "--executable", "--no-default-library",
  ])

  inspect(opts.no_default_lib, content="true")
}

///|
test "parse_args accepts repeated --input option" {
  let opts = parse_args([
    "mbtld", "-o", "out.o", "--input", "a.o", "--input", "libx.a",
  ])

  assert_true(opts.input_files.contains("a.o"))
  assert_true(opts.input_files.contains("libx.a"))
}

///|
test "parse_args accepts pasld smartlinking alias" {
  let opts = parse_args([
    "mbtld", "-o", "out.o", "--relocatable", "--smartlinking",
  ])

  inspect(opts.smart_linking, content="true")
}

///|
test "parse_args supports hex start-address" {
  let opts = parse_args([
    "mbtld", "-o", "a.out", "--executable", "--start-address", "0x400000",
  ])

  inspect(opts.start_address, content="4194304")
}

///|
test "parse_args supports scaled linker-heap-size suffix" {
  let opts = parse_args([
    "mbtld", "-o", "out.so", "--shared", "--linker-heap-size", "1M",
  ])

  inspect(opts.linker_heap_size, content="Some(1048576)")
}
