///| CLI main logic

///|
/// Run CLI and return exit code
pub fn run_cli(args : Array[String]) -> Int {
  try {
    let opts = parse_args(args)
    let artifact = @linker.link(opts)
    write_output(opts.output, artifact.bytes)
    if opts.verbose {
      println("Output written to: \{opts.output}")
    }
    0
  } catch {
    @ir.Cli(e) => {
      println("CLI error: \{format_cli_error(e)}")
      1
    }
    @ir.Elf(e) => {
      println("ELF error: \{format_elf_error(e)}")
      2
    }
    @ir.Resolve(e) => {
      println("Resolve error: \{format_resolve_error(e)}")
      3
    }
    @ir.Reloc(e) => {
      println("Relocation error: \{format_reloc_error(e)}")
      4
    }
    @ir.Write(e) => {
      println("Write error: \{format_write_error(e)}")
      5
    }
    @ir.InvalidArgs(msg) => {
      println("Invalid arguments: \{msg}")
      6
    }
    @ir.MissingValue(flag) => {
      println("Missing value for flag: \{flag}")
      7
    }
    @ir.UnsupportedFlag(flag) => {
      println("Unsupported flag: \{flag}")
      8
    }
    _ => abort("unreachable")
  }
}

///|
fn write_output(path : String, bytes : Bytes) -> Unit raise @ir.LinkError {
  @fs.write_bytes_to_file(path, bytes) catch {
    @fs.IOError(msg) =>
      raise @ir.Write(SerializeFailure("cannot write output \{path}: \{msg}"))
  }
}

///|
fn format_cli_error(e : @ir.CliError) -> String {
  match e {
    InvalidArgs(msg) => msg
    MissingValue(flag) => "missing value for \{flag}"
    UnsupportedFlag(flag) => "unsupported flag: \{flag}"
  }
}

///|
fn format_elf_error(e : @ir.ElfError) -> String {
  match e {
    BadSignature(msg) => "bad signature: \{msg}"
    UnsupportedClass(msg) => "unsupported class: \{msg}"
    UnsupportedMachine(msg) => "unsupported machine: \{msg}"
    InvalidObjectType(msg) => "invalid object type: \{msg}"
    CorruptArchive(msg) => "corrupt archive: \{msg}"
    TruncatedFile(msg) => "truncated file: \{msg}"
    InvalidSection(msg) => "invalid section: \{msg}"
    InvalidSymbol(msg) => "invalid symbol: \{msg}"
    InvalidRelocation(msg) => "invalid relocation: \{msg}"
  }
}

///|
fn format_resolve_error(e : @ir.ResolveError) -> String {
  match e {
    UndefinedSymbol(name) => "undefined symbol: \{name}"
    MultipleDefinition(name) => "multiple definition: \{name}"
    SectionConflict(msg) => "section conflict: \{msg}"
  }
}

///|
fn format_reloc_error(e : @ir.RelocError) -> String {
  match e {
    UnsupportedRelocType(t) => "unsupported relocation type: \{t}"
    RelocOverflow(msg) => "relocation overflow: \{msg}"
    BadRelocTarget(msg) => "bad relocation target: \{msg}"
  }
}

///|
fn format_write_error(e : @ir.WriteError) -> String {
  match e {
    LayoutFailure(msg) => "layout failure: \{msg}"
    InvalidOutputKind(msg) => "invalid output kind: \{msg}"
    SerializeFailure(msg) => "serialize failure: \{msg}"
  }
}
