///|
/// Linker public API

///|
fn load_inputs_from_paths(
  paths : Array[String],
) -> Array[@ir.InputObject] raise @ir.LinkError {
  if paths.length() == 0 {
    raise Cli(@ir.InvalidArgs("no input files"))
  }

  let inputs : Array[@ir.InputObject] = []
  for path in paths {
    let data = @fs.read_file_to_bytes(path) catch {
      @fs.IOError(msg) =>
        raise Elf(@ir.TruncatedFile("cannot read file \{path}: \{msg}"))
    }

    if @read.is_archive_magic(data[:]) {
      let members = @read.read_archive(data, path) catch {
        _ => raise Elf(@ir.CorruptArchive("failed to parse archive: \{path}"))
      }
      for entry in members {
        let parsed = @read.parse_object(entry.data, "\{path}:\{entry.name}") catch {
          _ =>
            raise Elf(
              @ir.InvalidObjectType(
                "failed to parse object from archive: \{path}:\{entry.name}",
              ),
            )
        }
        inputs.push(from_parsed_object(parsed))
      }
    } else {
      let parsed = @read.parse_object(data, path) catch {
        _ => raise Elf(@ir.InvalidObjectType("failed to parse object: \{path}"))
      }
      inputs.push(from_parsed_object(parsed))
    }
  }
  inputs
}

///|
/// Main entry point for linking
pub fn link(opts : @ir.LinkOptions) -> @ir.LinkArtifact raise @ir.LinkError {
  let inputs = load_inputs_from_paths(opts.input_files)
  let ir = build_ir(inputs, opts)
  let ir = @resolve.resolve_symbols(ir, opts) catch {
    UndefinedSymbol(msg) => raise Resolve(UndefinedSymbol(msg))
    MultipleDefinition(msg) => raise Resolve(MultipleDefinition(msg))
    SectionConflict(msg) => raise Resolve(SectionConflict(msg))
  }
  let ir = @resolve.merge_sections(ir, opts) catch {
    UndefinedSymbol(msg) => raise Resolve(UndefinedSymbol(msg))
    MultipleDefinition(msg) => raise Resolve(MultipleDefinition(msg))
    SectionConflict(msg) => raise Resolve(SectionConflict(msg))
  }
  let ir = @reloc.apply_relocations(ir, opts) catch {
    UnsupportedRelocType(t) => raise Reloc(UnsupportedRelocType(t))
    RelocOverflow(msg) => raise Reloc(RelocOverflow(msg))
    BadRelocTarget(msg) => raise Reloc(BadRelocTarget(msg))
  }

  match opts.output_kind {
    Relocatable =>
      @write.write_relocatable(ir, opts) catch {
        LayoutFailure(msg) => raise Write(LayoutFailure(msg))
        InvalidOutputKind(msg) => raise Write(InvalidOutputKind(msg))
        SerializeFailure(msg) => raise Write(SerializeFailure(msg))
      }
    ExecutablePie =>
      @write.write_pie_or_shared(ir, opts) catch {
        LayoutFailure(msg) => raise Write(LayoutFailure(msg))
        InvalidOutputKind(msg) => raise Write(InvalidOutputKind(msg))
        SerializeFailure(msg) => raise Write(SerializeFailure(msg))
      }
    SharedLibrary =>
      @write.write_pie_or_shared(ir, opts) catch {
        LayoutFailure(msg) => raise Write(LayoutFailure(msg))
        InvalidOutputKind(msg) => raise Write(InvalidOutputKind(msg))
        SerializeFailure(msg) => raise Write(SerializeFailure(msg))
      }
    _ => raise Write(InvalidOutputKind("unsupported output kind"))
  }
}
