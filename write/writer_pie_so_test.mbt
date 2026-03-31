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
test "write_pie_or_shared rejects relocatable kind" {
  let mut msg = ""
  try {
    ignore(write_pie_or_shared(pie_mk_ir(b"\x7fELF"), pie_test_opts(Relocatable)))
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
      {
        output_name: ".text",
        output_index: 0,
        align: 1UL,
        bytes: b"\xaa",
      },
      {
        output_name: ".data",
        output_index: 1,
        align: 1UL,
        bytes: b"\xbb\xcc",
      },
    ],
  }

  let artifact = write_pie_or_shared(ir, pie_test_opts(ExecutablePie)) catch {
    _ => abort("unexpected writer error")
  }

  inspect(artifact.bytes, content="b\"\\xaa\\xbb\\xcc\"")
}

///|
test "write_pie_or_shared fails on multi-input without merged sections" {
  let ir = {
    ..pie_mk_ir(b"\x7fELF"),
    input_objects: [
      pie_mk_input("a.o", b"A"),
      pie_mk_input("b.o", b"B"),
    ],
  }

  let mut msg = ""
  try {
    ignore(write_pie_or_shared(ir, pie_test_opts(SharedLibrary)))
    abort("expected writer error")
  } catch {
    LayoutFailure(m) => msg = m
    _ => abort("unexpected writer error type")
  }
  inspect(msg, content="no merged output sections for multi-input SharedLibrary build")
}
