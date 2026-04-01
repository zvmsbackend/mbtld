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
