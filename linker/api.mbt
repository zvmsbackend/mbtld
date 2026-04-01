///|
/// Linker public API

///|
pub struct LinkExecution {
  artifact : @ir.LinkArtifact
  diagnostics : Array[Diagnostic]
} derive(Show)

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
        _ => raise Elf(@ir.CorruptArchive("failed to parse archive \{path}"))
      }
      for entry in members {
        let parsed = @read.parse_object(entry.data, "\{path}:\{entry.name}") catch {
          _ =>
            raise Elf(
              @ir.InvalidObjectType(
                "failed to parse object from archive \{path}:\{entry.name}",
              ),
            )
        }
        inputs.push(from_parsed_object(parsed))
      }
    } else {
      let parsed = @read.parse_object(data, path) catch {
        _ => raise Elf(@ir.InvalidObjectType("failed to parse object \{path}"))
      }
      inputs.push(from_parsed_object(parsed))
    }
  }
  inputs
}

///|
/// Main entry point for linking
pub fn link_with_diagnostics(
  opts : @ir.LinkOptions,
) -> LinkExecution raise @ir.LinkError {
  let inputs = load_inputs_from_paths(opts.input_files)
  let pipeline = run_pipeline(inputs, opts)
  let ir = pipeline.ir

  let artifact = match opts.output_kind {
    Relocatable =>
      @write.write_relocatable(ir, opts) catch {
        e => raise Write(e)
      }
    ExecutablePie =>
      @write.write_pie_or_shared(ir, opts) catch {
        e => raise Write(e)
      }
    SharedLibrary =>
      @write.write_pie_or_shared(ir, opts) catch {
        e => raise Write(e)
      }
    EfiApplication =>
      @write.write_pie_or_shared(ir, opts) catch {
        e => raise Write(e)
      }
    EfiBootDriver =>
      @write.write_pie_or_shared(ir, opts) catch {
        e => raise Write(e)
      }
    EfiRuntimeDriver =>
      @write.write_pie_or_shared(ir, opts) catch {
        e => raise Write(e)
      }
  }

  { artifact, diagnostics: pipeline.diagnostics }
}

///|
/// Main entry point for linking
pub fn link(opts : @ir.LinkOptions) -> @ir.LinkArtifact raise @ir.LinkError {
  link_with_diagnostics(opts).artifact
}
