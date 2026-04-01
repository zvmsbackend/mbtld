///|
test "R_X86_64_64 writes little-endian value" {
  let input = b"\x00\x00\x00\x00\x00\x00\x00\x00"
  let out = apply_x86_64_reloc(input, 0, 1, 0x1122334455667788UL, 0, 0)
  assert_eq(out, b"\x88\x77\x66\x55\x44\x33\x22\x11")
}

///|
test "R_X86_64_32S overflow raises error" {
  let input = b"\x00\x00\x00\x00"
  let mut ok = false
  ignore(apply_x86_64_reloc(input, 0, 11, 0x1_0000_0000UL, 0, 0)) catch {
    RelocOverflow(_) => ok = true
    _ => abort("unexpected error type")
  }
  assert_true(ok)
}

///|
test "patch out-of-range raises bad target" {
  let input = b"\x00\x00\x00\x00"
  let mut ok = false
  ignore(apply_x86_64_reloc(input, 2, 1, 1, 0, 0)) catch {
    BadRelocTarget(_) => ok = true
    _ => abort("unexpected error type")
  }
  assert_true(ok)
}

///|
test "R_X86_64_PLT32 uses PC-relative patch formula" {
  let input = b"\x00\x00\x00\x00"
  let out = apply_x86_64_reloc(input, 0, 4, 0x20UL, 0, 4)
  assert_eq(out, b"\x1c\x00\x00\x00")
}

///|
test "R_X86_64_PC64 writes signed 64-bit relative value" {
  let input = b"\x00\x00\x00\x00\x00\x00\x00\x00"
  let out = apply_x86_64_reloc(input, 0, 24, 0x110UL, -16L, 0x100UL)
  assert_eq(out, b"\x00\x00\x00\x00\x00\x00\x00\x00")
}

///|
test "R_X86_64_JUMP_SLOT writes absolute 64-bit value" {
  let input = b"\x00\x00\x00\x00\x00\x00\x00\x00"
  let out = apply_x86_64_reloc(input, 0, 7, 0x1234UL, 0, 0)
  assert_eq(out, b"\x34\x12\x00\x00\x00\x00\x00\x00")
}

///|
test "R_X86_64_16 overflow raises error" {
  let input = b"\x00\x00"
  let mut ok = false
  ignore(apply_x86_64_reloc(input, 0, 12, 0x1_0000UL, 0, 0)) catch {
    RelocOverflow(_) => ok = true
    _ => abort("unexpected error type")
  }
  assert_true(ok)
}
