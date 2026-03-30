///|
test "is_elf_magic detects ELF magic bytes" {
  // Valid ELF magic
  let elf_bytes : Bytes = [0x7f, 'E', 'L', 'F', 0x02, 0x01, 0x01, 0x00]
  inspect(elf_bytes, content="b\"\\x7fELF\\x02\\x01\\x01\\x00\"")
  assert_true(is_elf_magic(elf_bytes[:]))

  // Invalid magic
  let invalid_bytes : Bytes = [0x7f, 'E', 'L', 'X']
  assert_true(!is_elf_magic(invalid_bytes[:]))
}

///|
test "is_archive_magic detects archive magic" {
  // Valid archive magic "!<arch>\n"
  let ar_bytes : Bytes = ['!', '<', 'a', 'r', 'c', 'h', '>', '\n']
  assert_true(is_archive_magic(ar_bytes[:]))

  // Invalid magic
  let invalid_bytes : Bytes = ['!', '<', 'a', 'r', 'c', 'h', '>', ' ']
  assert_true(!is_archive_magic(invalid_bytes[:]))
}

///|
test "read_cstring extracts null-terminated string" {
  let data : Bytes = ['h', 'e', 'l', 'l', 'o', 0, 'w', 'o', 'r', 'l', 'd', 0]
  let str = read_cstring(data[:], 0)
  inspect(str, content="hello")

  let str2 = read_cstring(data[:], 6)
  inspect(str2, content="world")
}

///|
test "IoCursor reads little-endian integers" {
  let data : Bytes = [0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]
  let cursor = @base.IoCursor::new(data)

  let val = cursor.read_u32_le() |> unwrap
  inspect(val, content="1")

  let val2 = cursor.read_u32_le() |> unwrap
  inspect(val2, content="2")
}

///|
fn unwrap(result : Result[UInt, String]) -> UInt {
  match result {
    Ok(v) => v
    Err(msg) => abort("unwrap failed: \{msg}")
  }
}
