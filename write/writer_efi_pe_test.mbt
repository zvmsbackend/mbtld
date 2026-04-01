///|
fn efi_test_opts(kind : @ir.OutputKind) -> @ir.LinkOptions {
  {
    output: "bootx64.efi",
    output_kind: kind,
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
fn efi_mk_ir() -> @ir.LinkIr {
  {
    arch: X86_64,
    bitness: ELF64,
    input_objects: [
      {
        path: "a.o",
        raw: b"A",
        arch: X86_64,
        bitness: ELF64,
        sections: [],
        symbols: [],
        relocs: [],
      },
    ],
    merged_sections: [],
    merged_symbols: [],
    pending_relocs: [],
  }
}

///|
fn efi_mk_ir_riscv64() -> @ir.LinkIr {
  {
    ..efi_mk_ir(),
    arch: RISCV64,
    input_objects: [
      {
        path: "a.o",
        raw: b"A",
        arch: RISCV64,
        bitness: ELF64,
        sections: [],
        symbols: [],
        relocs: [],
      },
    ],
  }
}

///|
fn efi_read_u16_le(bytes : Bytes, off : Int) -> UInt16 {
  (bytes[off].to_uint() | (bytes[off + 1].to_uint() << 8)).to_uint16()
}

///|
fn efi_read_u32_le(bytes : Bytes, off : Int) -> UInt {
  bytes[off].to_uint() |
  (bytes[off + 1].to_uint() << 8) |
  (bytes[off + 2].to_uint() << 16) |
  (bytes[off + 3].to_uint() << 24)
}

///|
test "write_efi_image rejects non-efi output kind" {
  let mut msg = ""
  try {
    ignore(write_efi_image(efi_mk_ir(), efi_test_opts(Relocatable)))
    abort("expected writer error")
  } catch {
    InvalidOutputKind(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(msg, content="write_efi_image only supports EFI output kinds")
}

///|
test "write_efi_image fails when merged sections are absent" {
  let mut msg = ""
  try {
    ignore(write_efi_image(efi_mk_ir(), efi_test_opts(EfiApplication)))
    abort("expected writer error")
  } catch {
    LayoutFailure(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(msg, content="no merged output sections for EFI build")
}

///|
test "write_efi_image emits PE headers and EFI subsystem" {
  let ir = {
    ..efi_mk_ir(),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "efi_main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_efi_image(ir, efi_test_opts(EfiApplication))
  let bytes = artifact.bytes

  inspect(bytes[0].to_uint(), content="77")
  inspect(bytes[1].to_uint(), content="90")
  inspect(bytes[0x80].to_uint(), content="80")
  inspect(bytes[0x81].to_uint(), content="69")
  inspect(efi_read_u16_le(bytes, 0x84), content="34404")
  inspect(efi_read_u16_le(bytes, 0x84 + 20 + 68), content="10")
}

///|
test "write_efi_image uses efi_main fallback as entry" {
  let ir = {
    ..efi_mk_ir(),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "efi_main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_efi_image(ir, efi_test_opts(EfiApplication))
  let bytes = artifact.bytes
  inspect(efi_read_u32_le(bytes, 0x84 + 20 + 16), content="4096")
}

///|
test "write_efi_image enforces executable entry symbol" {
  let ir = {
    ..efi_mk_ir(),
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

  let mut msg = ""
  try {
    ignore(write_efi_image(ir, efi_test_opts(EfiRuntimeDriver)))
    abort("expected writer error")
  } catch {
    LayoutFailure(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(
    msg,
    content="EFI output requires an executable entry symbol (efi_main/_start/main or --entry-point)",
  )
}

///|
test "write_efi_image supports riscv64 machine id" {
  let ir = {
    ..efi_mk_ir_riscv64(),
    merged_sections: [
      {
        output_name: ".text",
        output_index: 0,
        align: 1UL,
        bytes: b"\x13\x00\x00\x00",
      },
    ],
    merged_symbols: [
      {
        name: "efi_main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_efi_image(ir, efi_test_opts(EfiApplication))
  inspect(efi_read_u16_le(artifact.bytes, 0x84), content="20580")
}

///|
test "write_efi_image sets EFI boot/runtime subsystem values" {
  let base_ir = {
    ..efi_mk_ir(),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "efi_main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let boot = write_efi_image(base_ir, efi_test_opts(EfiBootDriver))
  let runtime = write_efi_image(base_ir, efi_test_opts(EfiRuntimeDriver))
  inspect(efi_read_u16_le(boot.bytes, 0x84 + 20 + 68), content="11")
  inspect(efi_read_u16_le(runtime.bytes, 0x84 + 20 + 68), content="12")
}

///|
test "write_efi_image rejects unsupported efi architecture" {
  let ir = {
    ..efi_mk_ir(),
    arch: LOONGARCH64,
    input_objects: [
      {
        path: "a.o",
        raw: b"A",
        arch: LOONGARCH64,
        bitness: ELF64,
        sections: [],
        symbols: [],
        relocs: [],
      },
    ],
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
        name: "efi_main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let mut msg = ""
  try {
    ignore(write_efi_image(ir, efi_test_opts(EfiApplication)))
    abort("expected writer error")
  } catch {
    InvalidOutputKind(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(
    msg,
    content="EFI PE/COFF writer currently supports x86_64, aarch64 and riscv64",
  )
}

///|
test "write_efi_image emits base relocation directory and section" {
  let ir = {
    ..efi_mk_ir(),
    merged_sections: [
      {
        output_name: ".text",
        output_index: 0,
        align: 8UL,
        bytes: b"\x00\x00\x00\x00\x00\x00\x00\x00",
      },
    ],
    merged_symbols: [
      {
        name: "efi_main",
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
        rel_type: @model.R_X86_64_64,
        target_sym: 0,
        addend: 0,
        has_addend: true,
      },
    ],
  }

  let artifact = write_efi_image(ir, efi_test_opts(EfiApplication))
  let bytes = artifact.bytes
  let reloc_dir_off = 0x84 + 20 + 112 + 8 * 5
  let reloc_rva = efi_read_u32_le(bytes, reloc_dir_off)
  let reloc_size = efi_read_u32_le(bytes, reloc_dir_off + 4)
  inspect(reloc_rva > 0, content="true")
  inspect(reloc_size >= 8, content="true")

  let e_lfanew = efi_read_u32_le(bytes, 0x3C).reinterpret_as_int()
  let sec_count = efi_read_u16_le(bytes, e_lfanew + 6).to_int()
  let size_opt = efi_read_u16_le(bytes, e_lfanew + 20).to_int()
  let sec_off = e_lfanew + 24 + size_opt
  let mut found = false
  for i in 0..<sec_count {
    let sh = sec_off + i * 40
    let name = bytes[sh:sh + 8].to_bytes().to_string()
    let rva = efi_read_u32_le(bytes, sh + 12)
    if name.contains(".reloc") {
      found = true
      inspect(rva, content="\{reloc_rva}")
    }
  }
  inspect(found, content="true")
}

///|
test "write_efi_image keeps relocation directory empty when no relocs" {
  let ir = {
    ..efi_mk_ir(),
    merged_sections: [
      { output_name: ".text", output_index: 0, align: 1UL, bytes: b"\x90\xC3" },
    ],
    merged_symbols: [
      {
        name: "efi_main",
        output_sec: 0,
        output_value: 0UL,
        binding: Global,
        ty: Func,
        vis: Default,
      },
    ],
  }

  let artifact = write_efi_image(ir, efi_test_opts(EfiApplication))
  let bytes = artifact.bytes
  let reloc_dir_off = 0x84 + 20 + 112 + 8 * 5
  inspect(efi_read_u32_le(bytes, reloc_dir_off), content="0")
  inspect(efi_read_u32_le(bytes, reloc_dir_off + 4), content="0")
}
