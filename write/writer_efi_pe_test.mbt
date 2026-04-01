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
