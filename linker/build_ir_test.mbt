///|
fn bir_mk_section(name : String, data : Bytes) -> @ir.SectionRec {
  {
    name,
    name_hash: name.hash().to_uint64(),
    ty: 1,
    flags: 0UL,
    align: 1UL,
    data,
    info: 0,
    link: 0,
  }
}

///|
fn bir_mk_symbol(
  name : String,
  sec_index : Int,
  value : UInt64,
) -> @ir.SymbolRec {
  {
    name,
    name_hash: name.hash().to_uint64(),
    binding: Global,
    ty: Func,
    vis: Default,
    sec_index,
    value,
    size: 0UL,
  }
}

///|
fn bir_mk_opts() -> @ir.LinkOptions {
  {
    output: "out.o",
    output_kind: Relocatable,
    entry: "",
    signature: None,
    input_files: [],
    dynamic_libs: [],
    dynamic_linker: None,
    strip_symbols: false,
    strip_debug: false,
    no_default_lib: false,
    smart_linking: false,
    linker_heap_no_smart: false,
    linker_heap_size: None,
    linker_block_size: None,
    linker_block_power: None,
    linker_block_level: None,
    section_align: 4096,
    start_address: 0,
    verbose: false,
  }
}

///|
test "build_ir merges same-name sections" {
  let obj1 : @ir.InputObject = {
    path: "a.o",
    raw: b"A",
    arch: X86_64,
    bitness: ELF64,
    sections: [bir_mk_section(".text", b"\x01\x02")],
    symbols: [bir_mk_symbol("foo", 0, 0UL)],
    relocs: [],
  }

  let obj2 : @ir.InputObject = {
    path: "b.o",
    raw: b"B",
    arch: X86_64,
    bitness: ELF64,
    sections: [bir_mk_section(".text", b"\x03")],
    symbols: [bir_mk_symbol("bar", 0, 0UL)],
    relocs: [],
  }

  let ir = build_ir([obj1, obj2], bir_mk_opts())

  inspect(ir.merged_sections.length(), content="1")
  inspect(ir.merged_sections[0].bytes, content="b\"\\x01\\x02\\x03\"")
  inspect(ir.merged_symbols.length(), content="2")
  inspect(ir.merged_symbols[0].name, content="foo")
  inspect(ir.merged_symbols[1].name, content="bar")
  inspect(ir.merged_symbols[1].output_value, content="2")
}

///|
test "build_ir maps relocation target symbol" {
  let obj : @ir.InputObject = {
    path: "a.o",
    raw: b"A",
    arch: X86_64,
    bitness: ELF64,
    sections: [bir_mk_section(".text", b"\x90\x90\x90\x90")],
    symbols: [bir_mk_symbol("foo", 0, 0UL)],
    relocs: [
      {
        sec_index: 0,
        offset: 1UL,
        rel_type: 2,
        sym_index: 0,
        addend: 0,
        has_addend: true,
      },
    ],
  }

  let ir = build_ir([obj], bir_mk_opts())
  inspect(ir.pending_relocs.length(), content="1")
  inspect(ir.pending_relocs[0].out_sec, content="0")
  inspect(ir.pending_relocs[0].patch_off, content="1")
  inspect(ir.pending_relocs[0].target_sym, content="0")
}

///|
test "build_ir normalizes and orders output sections" {
  let obj : @ir.InputObject = {
    path: "a.o",
    raw: b"A",
    arch: X86_64,
    bitness: ELF64,
    sections: [
      bir_mk_section(".rodata.str1.1", b"abc\x00"),
      bir_mk_section(".text.hot", b"\x90"),
    ],
    symbols: [bir_mk_symbol("foo", 1, 0UL), bir_mk_symbol("c1", 0, 0UL)],
    relocs: [],
  }

  let ir = build_ir([obj], bir_mk_opts())

  inspect(ir.merged_sections.length(), content="2")
  inspect(ir.merged_sections[0].output_name, content=".text")
  inspect(ir.merged_sections[1].output_name, content=".rodata")
  inspect(ir.merged_symbols[0].output_sec, content="0")
  inspect(ir.merged_symbols[1].output_sec, content="1")
}
