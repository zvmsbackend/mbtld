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
