///|
test "parse_args rejects missing input-path" {
  let mut ok = false
  try {
    ignore(
      parse_args([
        "mbtld", "-o", "out.o", "--input-path", "/tmp/mbtld/path/that/does/not/exist",
      ]),
    )
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
