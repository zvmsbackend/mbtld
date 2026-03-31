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

  let artifact = write_pie_or_shared(ir, pie_test_opts(ExecutablePie))

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
test "write_pie_or_shared emits interp for executable pie" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\xaa" },
      { output_name: ".data", output_index: 1, align: 1UL, bytes: b"\xbb" },
    ],
  }
  let opts = {
    ..pie_test_opts(ExecutablePie),
    dynamic_linker: Some("/lib64/ld-linux-x86-64.so.2"),
  }

  let artifact = write_pie_or_shared(ir, opts)

  inspect(artifact.bytes[56], content="b'\\x04'")
  inspect(artifact.bytes[176], content="b'\\x03'")
  let interp_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  inspect(artifact.bytes[interp_off], content="b'\\x2F'")
  inspect(artifact.bytes[232], content="b'\\x02'")
}

///|
test "write_pie_or_shared writes e_entry from entry symbol" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      {
        output_name: ".text",
        output_index: 0,
        align: 1UL,
        bytes: b"\x90\x90\xC3",
      },
    ],
    merged_symbols: [
      {
        name: "_start",
        output_sec: 0,
        output_value: 1UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }
  let opts = { ..pie_test_opts(ExecutablePie), entry: "_start" }

  let artifact = write_pie_or_shared(ir, opts)

  // data_start is fixed at ELF64_EHDR_SIZE + 4 * ELF64_PHDR_SIZE = 0x120.
  inspect(pie_read_u64_le(artifact.bytes, 24), content="289")
}

///|
test "write_pie_or_shared defaults e_entry to _start for executable pie" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "_start",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_pie_or_shared(ir, pie_test_opts(ExecutablePie))

  // data_start is fixed at ELF64_EHDR_SIZE + 4 * ELF64_PHDR_SIZE = 0x120.
  inspect(pie_read_u64_le(artifact.bytes, 24), content="288")
}

///|
test "write_pie_or_shared defaults e_entry to main when _start missing" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "main",
        output_sec: 0,
        output_value: 1UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_pie_or_shared(ir, pie_test_opts(ExecutablePie))

  inspect(pie_read_u64_le(artifact.bytes, 24), content="289")
}

///|
test "write_pie_or_shared ignores explicit data symbol as entry" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".data", output_index: 0, align: 1UL, bytes: b"\x01" },
    ],
    merged_symbols: [
      {
        name: "main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Object,
        vis: Default,
      },
    ],
  }
  let opts = { ..pie_test_opts(ExecutablePie), entry: "main" }

  let artifact = write_pie_or_shared(ir, opts)

  inspect(pie_read_u64_le(artifact.bytes, 24), content="0")
}

///|
test "write_pie_or_shared fallback skips data main symbol" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".data", output_index: 0, align: 1UL, bytes: b"\x01" },
    ],
    merged_symbols: [
      {
        name: "main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Object,
        vis: Default,
      },
    ],
  }

  let artifact = write_pie_or_shared(ir, pie_test_opts(ExecutablePie))

  inspect(pie_read_u64_le(artifact.bytes, 24), content="0")
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
  )

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
test "write_pie_or_shared emits rela.dyn and DT_RELA tags" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 8UL, bytes: b"\x90\xC3" },
      { output_name: ".data", output_index: 1, align: 8UL, bytes: b"\x00\x00" },
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
      {
        out_sec: 1,
        patch_off: 0UL,
        rel_type: @model.R_X86_64_64,
        target_sym: 0,
        addend: 5L,
        has_addend: true,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut rela_off = 0UL
  let mut rela_size = 0UL
  let mut rela_entsize = 0UL
  let mut rela_link = 0U
  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    if sh_type == @model.SHT_RELA {
      rela_off = pie_read_u64_le(artifact.bytes, sh_off + 24)
      rela_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
      rela_link = pie_read_u32_le(artifact.bytes, sh_off + 40)
      rela_entsize = pie_read_u64_le(artifact.bytes, sh_off + 56)
    }
  }

  inspect(rela_size, content="24")
  inspect(rela_entsize, content="24")
  inspect(rela_link > 0, content="true")

  let rela_entry_off = rela_off.to_int()
  inspect(pie_read_u64_le(artifact.bytes, rela_entry_off), content="296")
  inspect(
    pie_read_u64_le(artifact.bytes, rela_entry_off + 8),
    content="4294967297",
  )
  inspect(pie_read_u64_le(artifact.bytes, rela_entry_off + 16), content="5")

  let dyn_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  let mut has_dt_rela = false
  let mut has_dt_relasz = false
  let mut has_dt_relaent = false
  for i in 0..<16 {
    let tag = pie_read_u64_le(artifact.bytes, dyn_off + i * 16)
    let val = pie_read_u64_le(artifact.bytes, dyn_off + i * 16 + 8)
    if tag == 7UL {
      has_dt_rela = val > 0UL
    }
    if tag == 8UL {
      has_dt_relasz = val == 24UL
    }
    if tag == 9UL {
      has_dt_relaent = val == 24UL
    }
    if tag == 0UL {
      break
    }
  }

  inspect(has_dt_rela, content="true")
  inspect(has_dt_relasz, content="true")
  inspect(has_dt_relaent, content="true")
}

///|
test "write_pie_or_shared emits rela.plt and DT_JMPREL tags" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 8UL, bytes: b"\x90\xC3" },
      { output_name: ".data", output_index: 1, align: 8UL, bytes: b"\x00\x00" },
    ],
    merged_symbols: [
      {
        name: "puts",
        output_sec: -1,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
    pending_relocs: [
      {
        out_sec: 1,
        patch_off: 0UL,
        rel_type: @model.R_X86_64_JUMP_SLOT,
        target_sym: 0,
        addend: 0L,
        has_addend: true,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut rela_off = 0UL
  let mut rela_size = 0UL
  let mut rela_entsize = 0UL
  let mut rela_info = 0U
  let mut got_plt_idx = -1
  let mut got_plt_addr = 0UL
  let mut got_plt_size = 0UL
  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    let sh_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
    let sh_addr = pie_read_u64_le(artifact.bytes, sh_off + 16)
    let sh_entsize_val = pie_read_u64_le(artifact.bytes, sh_off + 56)
    if sh_type == @model.SHT_RELA {
      rela_off = pie_read_u64_le(artifact.bytes, sh_off + 24)
      rela_size = sh_size
      rela_info = pie_read_u32_le(artifact.bytes, sh_off + 44)
      rela_entsize = sh_entsize_val
    }
    if sh_type == @model.SHT_PROGBITS &&
      sh_size == 32UL &&
      sh_entsize_val == 0UL {
      got_plt_idx = i
      got_plt_addr = sh_addr
      got_plt_size = sh_size
    }
  }

  inspect(rela_size, content="24")
  inspect(rela_entsize, content="24")
  inspect(rela_info, content="\{got_plt_idx.reinterpret_as_uint()}")
  inspect(got_plt_size, content="32")

  let rela_entry_off = rela_off.to_int()
  inspect(
    pie_read_u64_le(artifact.bytes, rela_entry_off),
    content="\{got_plt_addr + 24UL}",
  )
  inspect(
    pie_read_u64_le(artifact.bytes, rela_entry_off + 8),
    content="4294967303",
  )
  inspect(pie_read_u64_le(artifact.bytes, rela_entry_off + 16), content="0")

  let dyn_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  let mut has_dt_pltrelsz = false
  let mut has_dt_pltrel = false
  let mut has_dt_jmprel = false
  for i in 0..<16 {
    let tag = pie_read_u64_le(artifact.bytes, dyn_off + i * 16)
    let val = pie_read_u64_le(artifact.bytes, dyn_off + i * 16 + 8)
    if tag == 2UL {
      has_dt_pltrelsz = val == 24UL
    }
    if tag == 20UL {
      has_dt_pltrel = val == 7UL
    }
    if tag == 23UL {
      has_dt_jmprel = val > 0UL
    }
    if tag == 0UL {
      break
    }
  }

  inspect(has_dt_pltrelsz, content="true")
  inspect(has_dt_pltrel, content="true")
  inspect(has_dt_jmprel, content="true")
}

///|
test "write_pie_or_shared emits got.plt and DT_PLTGOT tag" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 8UL, bytes: b"\x90\xC3" },
      { output_name: ".data", output_index: 1, align: 8UL, bytes: b"\x00\x00" },
    ],
    merged_symbols: [
      {
        name: "puts",
        output_sec: -1,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
    pending_relocs: [
      {
        out_sec: 1,
        patch_off: 0UL,
        rel_type: @model.R_X86_64_JUMP_SLOT,
        target_sym: 0,
        addend: 0L,
        has_addend: true,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut got_plt_addr = 0UL
  let mut got_plt_size = 0UL
  let mut got_plt_off = 0UL
  let mut dynamic_addr = 0UL
  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    let sh_off_val = pie_read_u64_le(artifact.bytes, sh_off + 24)
    let sh_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
    let sh_addr = pie_read_u64_le(artifact.bytes, sh_off + 16)
    let sh_entsize_val = pie_read_u64_le(artifact.bytes, sh_off + 56)
    // .got.plt is PROGBITS + alloc/write with entsize 0 and size 32 for 1 JUMP_SLOT entry.
    if sh_type == @model.SHT_PROGBITS &&
      sh_size == 32UL &&
      sh_entsize_val == 0UL {
      got_plt_off = sh_off_val
      got_plt_addr = sh_addr
      got_plt_size = sh_size
    }
    if sh_type == @model.SHT_DYNAMIC {
      dynamic_addr = sh_addr
    }
  }

  inspect(got_plt_size, content="32")
  inspect(
    pie_read_u64_le(artifact.bytes, got_plt_off.to_int()),
    content="\{dynamic_addr}",
  )

  let dyn_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  let mut has_dt_pltgot = false
  for i in 0..<20 {
    let tag = pie_read_u64_le(artifact.bytes, dyn_off + i * 16)
    let val = pie_read_u64_le(artifact.bytes, dyn_off + i * 16 + 8)
    if tag == 3UL {
      has_dt_pltgot = val == got_plt_addr && got_plt_addr > 0UL
    }
    if tag == 0UL {
      break
    }
  }
  inspect(has_dt_pltgot, content="true")
}

///|
test "write_pie_or_shared emits plt section for jump slot relocations" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 8UL, bytes: b"\x90\xC3" },
      { output_name: ".data", output_index: 1, align: 8UL, bytes: b"\x00\x00" },
    ],
    merged_symbols: [
      {
        name: "puts",
        output_sec: -1,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
    pending_relocs: [
      {
        out_sec: 1,
        patch_off: 0UL,
        rel_type: @model.R_X86_64_JUMP_SLOT,
        target_sym: 0,
        addend: 0L,
        has_addend: true,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut found_plt = false
  let mut plt_off = 0UL
  let mut plt_addr = 0UL
  let mut got_plt_off = 0UL
  let mut got_plt_addr = 0UL
  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    let sh_off_val = pie_read_u64_le(artifact.bytes, sh_off + 24)
    let sh_addr = pie_read_u64_le(artifact.bytes, sh_off + 16)
    let sh_flags = pie_read_u64_le(artifact.bytes, sh_off + 8)
    let sh_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
    let sh_entsize_val = pie_read_u64_le(artifact.bytes, sh_off + 56)
    if sh_type == @model.SHT_PROGBITS &&
      sh_size == 32UL &&
      sh_entsize_val == 16UL &&
      (sh_flags & @model.SHF_EXECINSTR) != 0UL {
      found_plt = true
      plt_off = sh_off_val
      plt_addr = sh_addr
    }
    if sh_type == @model.SHT_PROGBITS &&
      sh_size == 32UL &&
      sh_entsize_val == 0UL {
      got_plt_off = sh_off_val
      got_plt_addr = sh_addr
    }
  }

  inspect(found_plt, content="true")
  inspect(artifact.bytes[plt_off.to_int()].to_uint(), content="255")
  inspect(artifact.bytes[plt_off.to_int() + 1].to_uint(), content="53")
  // got.plt[3] should initially point to PLT1+6.
  inspect(
    pie_read_u64_le(artifact.bytes, got_plt_off.to_int() + 24),
    content="\{plt_addr + 22UL}",
  )
  inspect(got_plt_addr > 0UL, content="true")
}

///|
test "write_pie_or_shared keeps plt got and rela indices aligned" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 8UL, bytes: b"\x90\xC3" },
      {
        output_name: ".data",
        output_index: 1,
        align: 8UL,
        bytes: b"\x00\x00\x00\x00",
      },
    ],
    merged_symbols: [
      {
        name: "puts",
        output_sec: -1,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
      {
        name: "printf",
        output_sec: -1,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
    pending_relocs: [
      {
        out_sec: 1,
        patch_off: 0UL,
        rel_type: @model.R_X86_64_JUMP_SLOT,
        target_sym: 0,
        addend: 0L,
        has_addend: true,
      },
      {
        out_sec: 1,
        patch_off: 8UL,
        rel_type: @model.R_X86_64_JUMP_SLOT,
        target_sym: 1,
        addend: 0L,
        has_addend: true,
      },
    ],
  }

  let artifact = write_pie_or_shared(
    ir,
    pie_test_opts_with_libs(SharedLibrary, ["libc.so.6"]),
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut plt_addr = 0UL
  let mut plt_size = 0UL
  let mut got_plt_addr = 0UL
  let mut got_plt_off = 0UL
  let mut got_plt_size = 0UL
  let mut rela_plt_off = 0UL
  let mut rela_plt_size = 0UL

  for i in 0..<e_shnum {
    let sh_off = e_shoff + i * sh_entsize
    let sh_type = pie_read_u32_le(artifact.bytes, sh_off + 4)
    let sh_addr = pie_read_u64_le(artifact.bytes, sh_off + 16)
    let sh_off_val = pie_read_u64_le(artifact.bytes, sh_off + 24)
    let sh_size = pie_read_u64_le(artifact.bytes, sh_off + 32)
    let sh_entsize_val = pie_read_u64_le(artifact.bytes, sh_off + 56)
    let sh_info = pie_read_u32_le(artifact.bytes, sh_off + 44)

    if sh_type == @model.SHT_PROGBITS &&
      sh_size == 48UL &&
      sh_entsize_val == 16UL {
      plt_addr = sh_addr
      plt_size = sh_size
    }
    if sh_type == @model.SHT_PROGBITS &&
      sh_size == 40UL &&
      sh_entsize_val == 0UL {
      got_plt_addr = sh_addr
      got_plt_off = sh_off_val
      got_plt_size = sh_size
    }
    if sh_type == @model.SHT_RELA && sh_size == 48UL {
      rela_plt_off = sh_off_val
      rela_plt_size = sh_size
      inspect(sh_info > 0U, content="true")
    }
  }

  inspect(plt_size, content="48")
  inspect(got_plt_size, content="40")
  inspect(rela_plt_size, content="48")

  // got.plt slots should point at PLTn+6.
  inspect(
    pie_read_u64_le(artifact.bytes, got_plt_off.to_int() + 24),
    content="\{plt_addr + 22UL}",
  )
  inspect(
    pie_read_u64_le(artifact.bytes, got_plt_off.to_int() + 32),
    content="\{plt_addr + 38UL}",
  )

  // Rela entries should target got.plt slot addresses with matching sym indexes.
  let rela0 = rela_plt_off.to_int()
  let rela1 = rela0 + 24
  inspect(
    pie_read_u64_le(artifact.bytes, rela0),
    content="\{got_plt_addr + 24UL}",
  )
  inspect(pie_read_u64_le(artifact.bytes, rela0 + 8), content="4294967303")
  inspect(
    pie_read_u64_le(artifact.bytes, rela1),
    content="\{got_plt_addr + 32UL}",
  )
  inspect(pie_read_u64_le(artifact.bytes, rela1 + 8), content="8589934599")
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
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut dynsym_size = 0UL
  let mut dynsym_entsize = 0UL
  let mut dynsym_link = 0U
  for i in 0..<e_shnum {
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
  )

  let e_shoff = pie_read_u64_le(artifact.bytes, 40).to_int()
  let e_shnum = pie_read_u16_le(artifact.bytes, 60).to_int()
  let sh_entsize = pie_read_u16_le(artifact.bytes, 58).to_int()

  let mut dynsym_idx = -1
  let mut hash_idx = -1
  let mut hash_link = 0U
  let mut hash_entsize = 0UL
  let mut hash_off = 0UL
  let mut hash_size = 0UL

  for i in 0..<e_shnum {
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

  let artifact = write_pie_or_shared(ir, opts)

  let dyn_off = pie_read_u64_le(artifact.bytes, 184).to_int()
  // DT_SONAME should be first tag when no DT_NEEDED exists.
  inspect(pie_read_u64_le(artifact.bytes, dyn_off), content="14")
  let soname_off = pie_read_u64_le(artifact.bytes, dyn_off + 8)
  inspect(soname_off, content="1")
  // Then DT_STRTAB and DT_STRSZ.
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 16), content="5")
  inspect(pie_read_u64_le(artifact.bytes, dyn_off + 32), content="10")

  // Verify SONAME payload text is basename: "libmbtld.so".
  let strtab_addr = pie_read_u64_le(artifact.bytes, dyn_off + 24)
  let soname_pos = (strtab_addr + soname_off).to_int()
  inspect(artifact.bytes[soname_pos], content="b'\\x6C'")
  inspect(artifact.bytes[soname_pos + 3], content="b'\\x6D'")
  inspect(artifact.bytes[soname_pos + 7], content="b'\\x64'")
  inspect(artifact.bytes[soname_pos + 10], content="b'\\x6F'")
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
