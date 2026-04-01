///|
fn rc_opts(kind : @ir.OutputKind) -> @ir.LinkOptions {
  {
    output: "out.o",
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
fn rc_ir(arch : @ir.Arch) -> @ir.LinkIr {
  {
    arch,
    bitness: ELF64,
    input_objects: [],
    merged_sections: [
      {
        output_name: ".text",
        output_index: 0,
        align: 1UL,
        bytes: b"\x00\x00\x00\x00",
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
      {
        out_sec: 0,
        patch_off: 0UL,
        rel_type: 2,
        target_sym: 0,
        addend: 0,
        has_addend: true,
      },
    ],
  }
}

///|
fn rc_ir_with(arch : @ir.Arch, rel_type : UInt) -> @ir.LinkIr {
  {
    ..rc_ir(arch),
    merged_symbols: [
      {
        name: "foo",
        output_sec: 0,
        output_value: 1UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
    pending_relocs: [
      {
        out_sec: 0,
        patch_off: 0UL,
        rel_type,
        target_sym: 0,
        addend: 0,
        has_addend: true,
      },
    ],
  }
}

///|
test "apply_relocations skips patching for relocatable output" {
  let ir = rc_ir(X86_64)
  let out = apply_relocations(ir, rc_opts(Relocatable))
  inspect(out.merged_sections[0].bytes, content="b\"\\x00\\x00\\x00\\x00\"")
}

///|
test "apply_relocations patches AARCH64 ABS32 for executable output" {
  let ir = rc_ir_with(AARCH64, 258)
  let out = apply_relocations(ir, rc_opts(ExecutablePie))
  inspect(out.merged_sections[0].bytes, content="b\"\\x01\\x00\\x00\\x00\"")
}

///|
test "apply_relocations patches RISCV64 32-bit relocation" {
  let ir = rc_ir_with(RISCV64, 1)
  let out = apply_relocations(ir, rc_opts(ExecutablePie))
  inspect(out.merged_sections[0].bytes, content="b\"\\x01\\x00\\x00\\x00\"")
}

///|
test "apply_relocations patches LOONGARCH64 32-bit relocation" {
  let ir = rc_ir_with(LOONGARCH64, 1)
  let out = apply_relocations(ir, rc_opts(ExecutablePie))
  inspect(out.merged_sections[0].bytes, content="b\"\\x01\\x00\\x00\\x00\"")
}
