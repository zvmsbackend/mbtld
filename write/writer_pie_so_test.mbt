///|
fn pie_test_opts(kind : @ir.OutputKind) -> @ir.LinkOptions {
  {
    output: "a.out",
    output_kind: kind,
    entry: "",
    input_files: [],
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
fn pie_test_opts_with_libs(
  kind : @ir.OutputKind,
  libs : Array[String],
) -> @ir.LinkOptions {
  { ..pie_test_opts(kind), dynamic_libs: libs }
}

///|
fn pie_mk_input(path : String, raw : Bytes) -> @ir.InputObject {
  {
    path,
    raw,
    arch: X86_64,
    bitness: ELF64,
    sections: [],
    symbols: [],
    relocs: [],
  }
}

///|
fn pie_mk_ir(raw : Bytes) -> @ir.LinkIr {
  {
    arch: X86_64,
    bitness: ELF64,
    input_objects: [pie_mk_input("a.o", raw)],
    merged_sections: [],
    merged_symbols: [],
    pending_relocs: [],
  }
}

///|
fn pie_read_u64_le(bytes : Bytes, off : Int) -> UInt64 {
  bytes[off].to_uint64() |
  (bytes[off + 1].to_uint64() << 8) |
  (bytes[off + 2].to_uint64() << 16) |
  (bytes[off + 3].to_uint64() << 24) |
  (bytes[off + 4].to_uint64() << 32) |
  (bytes[off + 5].to_uint64() << 40) |
  (bytes[off + 6].to_uint64() << 48) |
  (bytes[off + 7].to_uint64() << 56)
}

///|
fn pie_read_u16_le(bytes : Bytes, off : Int) -> UInt16 {
  (bytes[off].to_uint() | (bytes[off + 1].to_uint() << 8)).to_uint16()
}

///|
fn pie_read_u32_le(bytes : Bytes, off : Int) -> UInt {
  bytes[off].to_uint() |
  (bytes[off + 1].to_uint() << 8) |
  (bytes[off + 2].to_uint() << 16) |
  (bytes[off + 3].to_uint() << 24)
}

///|
test "write_pie_or_shared rejects relocatable kind" {
  let mut msg = ""
  try {
    ignore(
      write_pie_or_shared(pie_mk_ir(b"\x7fELF"), pie_test_opts(Relocatable)),
    )
    abort("expected writer error")
  } catch {
    InvalidOutputKind(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(msg, content="write_pie_or_shared cannot emit relocatable output")
}

///|
test "write_pie_or_shared emits merged payload" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\xaa" },
      { output_name: ".data", output_index: 1, align: 1UL, bytes: b"\xbb\xcc" },
    ],
  }

  let artifact = write_pie_or_shared(ir, pie_test_opts(ExecutablePie)) catch {
    _ => abort("unexpected writer error")
  }

  inspect(artifact.bytes[0:4].to_bytes(), content="b\"\\x7fELF\"")
  inspect(artifact.bytes[16], content="b'\\x03'")
  inspect(artifact.bytes[17], content="b'\\x00'")
  inspect(artifact.bytes[32], content="b'\\x40'")
  inspect(artifact.bytes[54], content="b'\\x38'")
  inspect(artifact.bytes[56], content="b'\\x02'")
  inspect(artifact.bytes[64], content="b'\\x01'")
  inspect(artifact.bytes[68], content="b'\\x05'")
  inspect(artifact.bytes[120], content="b'\\x01'")
  inspect(artifact.bytes[124], content="b'\\x06'")
}

///|
test "write_pie_or_shared emits minimal dynamic metadata" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\xaa" },
      { output_name: ".data", output_index: 1, align: 1UL, bytes: b"\xbb\xcc" },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  ) catch {
    _ => abort("unexpected writer error")
  }

  // e_phnum=3 (RX, RW, PT_DYNAMIC)
  inspect(artifact.bytes[56], content="b'\\x03'")
  // Third PHDR type/flags
  inspect(artifact.bytes[176], content="b'\\x02'")
  inspect(artifact.bytes[180], content="b'\\x06'")

  let dyn_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  // DT_NEEDED("libc.so.6") and DT_SONAME("a.out")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off), content="1")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 8), content="7")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 16), content="14")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 24), content="1")
  // DT_STRTAB / DT_STRSZ / DT_HASH / DT_SYMTAB / DT_SYMENT / DT_NULL
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 32), content="5")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 48), content="10")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 64), content="4")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 80), content="6")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 96), content="11")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 112), content="0")
}

///|
test "write_pie_or_shared emits dynsym exported symbols" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "foo",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  ) catch {
    _ => abort("unexpected writer error")
  }

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut dynsym_size = 0UL
  let mut dynsym_entsize = 0UL
  let mut dynsym_link = 0U
  for i = 0; i < e_shnum; i = i + 1 {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    if sh_type == 11 {
      dynsym_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
      dynsym_link = pie_read_u32_le(artifact.bytes, sh_off + 40)
      dynsym_entsize = pie_read_u64_le(artifact.bytes, sh_off + 56)
    }
  }

  inspect(dynsym_size, content="48")
  inspect(dynsym_entsize, content="24")
  inspect(dynsym_link > 0, content="true")
}

///|
test "write_pie_or_shared emits hash section linked to dynsym" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "foo",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  ) catch {
    _ => abort("unexpected writer error")
  }

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut dynsym_idx = -1
  let mut hash_idx = -1
  let mut hash_link = 0U
  let mut hash_entsize = 0UL
  let mut hash_off = 0UL
  let mut hash_size = 0UL

  for i = 0; i < e_shnum; i = i + 1 {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    if sh_type == 11 {
      dynsym_idx = i
    }
    if sh_type == 5 {
      hash_idx = i
      hash_off = pie_read_u64_le(artifact.bytes, sh_off + 24)
      hash_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
      hash_link = pie_read_u32_le(artifact.bytes, sh_off + 40)
      hash_entsize = pie_read_u64_le(artifact.bytes, sh_off + 56)
    }
  }

  inspect(dynsym_idx >= 0, content="true")
  inspect(hash_idx >= 0, content="true")
  inspect(hash_link, content="\{dynsym_idx.reinterpret_as_uint()}")
  inspect(hash_entsize, content="4")

  // SysV hash table: nbucket=1, nchain=2, bucket[0]=1, chain[1]=0
  inspect(hash_size, content="20")
  inspect(pie_read_u32_le(artifact.bytes, hash_off.to_int()), content="1")
  inspect(pie_read_u32_le(artifact.bytes, hash_off.to_int() + 4), content="2")
  inspect(pie_read_u32_le(artifact.bytes, hash_off.to_int() + 8), content="1")
  inspect(pie_read_u32_le(artifact.bytes, hash_off.to_int() + 16), content="0")
}

///|
test "write_pie_or_shared emits soname without needed libs" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\xaa" },
    ],
  }
  let opts = {
    ..pie_test_opts_with_libs(SharedLibrary, []),
    output: "build/out/libmbtld.so",
  }

  let artifact = write_pie_or_shared(ir, opts) catch {
    _ => abort("unexpected writer error")
  }

  let dyn_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  // DT_SONAME should be first tag when no DT_NEEDED exists.
  inspect(pie_read_u64_le(artifact.bytes, dyn_off), content="14")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 8), content="1")
  // Then DT_STRTAB and DT_STRSZ.
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 16), content="5")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 32), content="10")
}

///|
test "write_pie_or_shared fails on multi-input without merged sections" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    input_objects: [pie_mk_input("a.o", b"A"), pie_mk_input("b.o", b"B")],
  }

  let mut msg = ""
  try {
    ignore(write_pie_or_shared(ir, pie_test_opts(SharedLibrary)))
    abort("expected writer error")
  } catch {
    LayoutFailure(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(
    msg,
    content="no merged output sections for multi-input SharedLibrary build",
  )
}
