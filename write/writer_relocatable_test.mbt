///|
fn test_opts() -> @ir.LinkOptions {
  {
    output: "a.o",
    output_kind: Relocatable,
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
fn mk_ir(inputs : Array[@ir.InputObject]) -> @ir.LinkIr {
  {
    arch: X86_64,
    bitness: ELF64,
    input_objects: inputs,
    merged_sections: [],
    merged_symbols: [],
    pending_relocs: [],
  }
}

///|
fn mk_input(path : String, raw : Bytes) -> @ir.InputObject {
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
fn rr_read_u16_le(bytes : Bytes, off : Int) -> UInt16 {
  (bytes[off].to_uint() | (bytes[off + 1].to_uint() << 8)).to_uint16()
}

///|
fn rr_read_u32_le(bytes : Bytes, off : Int) -> UInt {
  bytes[off].to_uint() |
  (bytes[off + 1].to_uint() << 8) |
  (bytes[off + 2].to_uint() << 16) |
  (bytes[off + 3].to_uint() << 24)
}

///|
fn rr_read_u64_le(bytes : Bytes, off : Int) -> UInt64 {
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
test "write_relocatable passthrough one object" {
  let raw = b"\x7fELF\x02\x01\x01\x00"
  let ir = mk_ir([mk_input("a.o", raw)])
  let artifact = write_relocatable(ir, test_opts())
  inspect(artifact.bytes, content="b\"\\x7fELF\\x02\\x01\\x01\\x00\"")
}

///|
test "write_relocatable rejects empty input" {
  let ir = mk_ir([])
  let mut msg = ""
  try {
    ignore(write_relocatable(ir, test_opts()))
    abort("expected writer error")
  } catch {
    LayoutFailure(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(msg, content="no input object to emit")
}

///|
test "write_relocatable emits merged section payload" {
  let raw = b"\x7fELF"
  let ir = {
    ..mk_ir([mk_input("a.o", raw)]),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x01\x02" },
      { output_name: ".data", output_index: 1, align: 1UL, bytes: b"\x03" },
    ],
  }

  let artifact = write_relocatable(ir, test_opts())

  inspect(artifact.bytes[0:4].to_bytes(), content="b\"\\x7fELF\"")
  inspect(artifact.bytes[16], content="b'\\x01'")
  inspect(artifact.bytes[17], content="b'\\x00'")
}

///|
test "write_relocatable emits symtab and strtab" {
  let raw = b"\x7fELF"
  let ir = {
    ..mk_ir([mk_input("a.o", raw)]),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90" },
    ],
    merged_symbols: [
      {
        name: "L0",
        output_sec: 0,
        output_value: 0UL,
        binding: Local,
        ty: NoType,
        vis: Default,
      },
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

  let artifact = write_relocatable(ir, test_opts())
  let bytes = artifact.bytes

  let e_shoff = rr_read_u64_le(bytes, 40).to_int()
  let e_shentsize = rr_read_u16_le(bytes, 58).to_int()
  let e_shnum = rr_read_u16_le(bytes, 60).to_int()

  let mut symtab_idx = -1
  let mut strtab_idx = -1
  let mut symtab_link = 0U
  let mut symtab_info = 0U
  let mut symtab_entsize = 0UL
  let mut symtab_size = 0UL
  let mut strtab_off = 0UL
  let mut strtab_size = 0UL

  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * e_shentsize
    let sh_type = rr_read_u32_le(bytes, sh_off + 4)
    if sh_type == 2 {
      symtab_idx = i
      symtab_link = rr_read_u32_le(bytes, sh_off + 40)
      symtab_info = rr_read_u32_le(bytes, sh_off + 44)
      symtab_size = rr_read_u64_le(bytes, sh_off + 32)
      symtab_entsize = rr_read_u64_le(bytes, sh_off + 56)
    }
    if sh_type == 3 && i > 0 {
      let sh_off_val = rr_read_u64_le(bytes, sh_off + 24)
      let sh_size_val = rr_read_u64_le(bytes, sh_off + 32)
      // Symbol strtab is the smaller STRTAB, shstrtab is usually larger.
      if strtab_idx < 0 || sh_size_val < strtab_size {
        strtab_idx = i
        strtab_off = sh_off_val
        strtab_size = sh_size_val
      }
    }
  }

  inspect(symtab_idx >= 0, content="true")
  inspect(strtab_idx >= 0, content="true")
  inspect(symtab_link, content="\{strtab_idx.reinterpret_as_uint()}")
  inspect(symtab_info, content="2")
  inspect(symtab_entsize, content="24")
  inspect(symtab_size, content="72")

  inspect(strtab_size, content="8")
  let base = strtab_off.to_int()
  inspect(bytes[base], content="b'\\x00'")
  inspect(bytes[base + 1], content="b'\\x4C'")
  inspect(bytes[base + 4], content="b'\\x66'")
  inspect(bytes[base + 7], content="b'\\x00'")
}

///|
test "write_relocatable emits rela section with symtab link" {
  let raw = b"\x7fELF"
  let ir = {
    ..mk_ir([mk_input("a.o", raw)]),
    merged_sections: [
      {
        output_name: ".text",
        output_index: 0,
        align: 1UL,
        bytes: b"\x90\x90\x90\x90",
      },
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
    pending_relocs: [
      { out_sec: 0, patch_off: 1UL, rel_type: 2, target_sym: 0, addend: 7 },
    ],
  }

  let artifact = write_relocatable(ir, test_opts())
  let bytes = artifact.bytes

  let e_shoff = rr_read_u64_le(bytes, 40).to_int()
  let e_shentsize = rr_read_u16_le(bytes, 58).to_int()
  let e_shnum = rr_read_u16_le(bytes, 60).to_int()

  let mut symtab_idx = -1
  let mut rela_idx = -1
  let mut rela_link = 0U
  let mut rela_info = 0U
  let mut rela_entsize = 0UL
  let mut rela_off = 0UL
  let mut rela_size = 0UL

  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * e_shentsize
    let sh_type = rr_read_u32_le(bytes, sh_off + 4)
    if sh_type == 2 {
      symtab_idx = i
    }
    if sh_type == 4 {
      rela_idx = i
      rela_link = rr_read_u32_le(bytes, sh_off + 40)
      rela_info = rr_read_u32_le(bytes, sh_off + 44)
      rela_entsize = rr_read_u64_le(bytes, sh_off + 56)
      rela_off = rr_read_u64_le(bytes, sh_off + 24)
      rela_size = rr_read_u64_le(bytes, sh_off + 32)
    }
  }

  inspect(symtab_idx >= 0, content="true")
  inspect(rela_idx >= 0, content="true")
  inspect(rela_link, content="\{symtab_idx.reinterpret_as_uint()}")
  inspect(rela_info, content="1")
  inspect(rela_entsize, content="24")
  inspect(rela_size, content="24")

  let r_off = rela_off.to_int()
  inspect(rr_read_u64_le(bytes, r_off), content="1")
  // r_info = (sym_index=1 << 32) | rel_type(2)
  inspect(rr_read_u64_le(bytes, r_off + 8), content="4294967298")
  inspect(rr_read_u64_le(bytes, r_off + 16), content="7")
}

///|
test "write_relocatable fails on multi-input without merged sections" {
  let ir = mk_ir([mk_input("a.o", b"A"), mk_input("b.o", b"B")])

  let mut msg = ""
  try {
    ignore(write_relocatable(ir, test_opts()))
    abort("expected writer error")
  } catch {
    LayoutFailure(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(
    msg,
    content="no merged output sections for multi-input relocatable build",
  )
}
