///|
test "R_AARCH64_ABS64 writes little-endian value" {
  let input = b"\x00\x00\x00\x00\x00\x00\x00\x00"
  let out = apply_aarch64_reloc(input, 0, 257, 0x1122334455667788UL, 0, 0)
  assert_eq(out, b"\x88\x77\x66\x55\x44\x33\x22\x11")
}

///|
test "R_AARCH64_PREL32 overflow raises error" {
  let input = b"\x00\x00\x00\x00"
  let mut ok = false
  ignore(apply_aarch64_reloc(input, 0, 261, 0x1_0000_0000UL, 0, 0)) catch {
    RelocOverflow(_) => ok = true
    _ => abort("unexpected error type")
  }
  assert_true(ok)
}

///|
test "aarch64 patch out-of-range raises bad target" {
  let input = b"\x00\x00\x00\x00"
  let mut ok = false
  ignore(apply_aarch64_reloc(input, 2, 257, 1, 0, 0)) catch {
    BadRelocTarget(_) => ok = true
    _ => abort("unexpected error type")
  }
  assert_true(ok)
}
