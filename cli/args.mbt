///| CLI argument parsing using argparse

///|
/// Define the linker command
fn linker_command() -> @argparse.Command {
  @argparse.Command::new(
    "mbtld",
    about="MoonBit Linker - A modern linker for ELF binaries",
    flags=[
      @argparse.FlagArg::new(
        "verbose",
        short='v',
        long="verbose",
        about="Enable verbose output",
      ),
      @argparse.FlagArg::new(
        "relocatable",
        short='r',
        long="relocatable",
        about="Generate relocatable output",
      ),
      @argparse.FlagArg::new(
        "executable",
        short='e',
        long="executable",
        about="Generate PIE executable",
      ),
      @argparse.FlagArg::new(
        "shared",
        short='s',
        long="shared",
        about="Generate shared library",
      ),
      @argparse.FlagArg::new(
        "dynamic-library",
        long="dynamic-library",
        about="Alias of --shared",
      ),
      @argparse.FlagArg::new(
        "efi-application",
        long="efi-application",
        about="Generate EFI application",
      ),
      @argparse.FlagArg::new(
        "efi-boot-driver",
        long="efi-boot-driver",
        about="Generate EFI boot driver",
      ),
      @argparse.FlagArg::new(
        "efi-runtime-driver",
        long="efi-runtime-driver",
        about="Generate EFI runtime driver",
      ),
      @argparse.FlagArg::new(
        "strip-symbols",
        long="strip-symbols",
        about="Strip symbol table",
      ),
      @argparse.FlagArg::new(
        "no-symbol-table",
        long="no-symbol-table",
        about="Alias of --strip-symbols",
      ),
      @argparse.FlagArg::new(
        "strip-debug",
        long="strip-debug",
        about="Strip debug information",
      ),
      @argparse.FlagArg::new(
        "no-debug-frame",
        long="no-debug-frame",
        about="Alias of --strip-debug",
      ),
      @argparse.FlagArg::new(
        "no-default-lib",
        long="no-default-lib",
        about="Do not link against default libraries",
      ),
      @argparse.FlagArg::new(
        "smart-linking",
        long="smart-linking",
        about="Enable smart linking optimizations",
      ),
      @argparse.FlagArg::new(
        "linker-heap-no-smart",
        long="linker-heap-no-smart",
        about="Disable smart adjustment for linker heap",
      ),
    ],
    options=[
      @argparse.OptionArg::new(
        "output",
        short='o',
        long="output",
        about="Output file path",
        required=true,
      ),
      @argparse.OptionArg::new(
        "entry",
        long="entry-point",
        about="Entry point symbol",
      ),
      @argparse.OptionArg::new(
        "alignment",
        long="alignment",
        about="Section alignment (default: 4096, or 'page'/'largepage')",
      ),
      @argparse.OptionArg::new(
        "start-address",
        long="start-address",
        about="Start address for output",
      ),
      @argparse.OptionArg::new(
        "dynamic-linker",
        long="dynamic-linker",
        about="Dynamic linker path",
      ),
      @argparse.OptionArg::new(
        "dynamic-linker-path",
        long="dynamic-linker-path",
        about="Alias of --dynamic-linker",
      ),
      @argparse.OptionArg::new(
        "include-dynamic-library",
        long="include-dynamic-library",
        about="Include dynamic library name (repeatable)",
      ),
      @argparse.OptionArg::new(
        "input-path",
        long="input-path",
        about="Include input files from a directory (*.o, *.a, *.ar)",
      ),
      @argparse.OptionArg::new(
        "input-path-with-subdirectory",
        long="input-path-with-subdirectory",
        about="Include input files recursively (*.o, *.a, *.ar)",
      ),
      @argparse.OptionArg::new(
        "include-dynamic-library-path",
        long="include-dynamic-library-path",
        about="Include dynamic libraries from a directory (*.so)",
      ),
      @argparse.OptionArg::new(
        "include-dynamic-library-path-with-subdirectory",
        long="include-dynamic-library-path-with-subdirectory",
        about="Include dynamic libraries recursively (*.so)",
      ),
      @argparse.OptionArg::new(
        "signature",
        long="signature",
        about="Signature marker to embed in output metadata",
      ),
      @argparse.OptionArg::new(
        "linker-heap-size",
        long="linker-heap-size",
        about="Linker heap size",
      ),
      @argparse.OptionArg::new(
        "linker-block-size",
        long="linker-block-size",
        about="Linker minimum block size",
      ),
      @argparse.OptionArg::new(
        "linker-block-power",
        long="linker-block-power",
        about="Linker accelerate block power",
      ),
      @argparse.OptionArg::new(
        "linker-block-level",
        long="linker-block-level",
        about="Linker block level",
      ),
    ],
    positionals=[
      @argparse.PositionArg::new(
        "inputs",
        about="Input object files",
        num_args=@argparse.ValueRange::new(lower=0, upper=1073741824),
      ),
    ],
  )
}

///|
/// Parse command line arguments into LinkOptions
pub fn parse_args(args : Array[String]) -> @ir.LinkOptions raise @ir.CliError {
  let cmd = linker_command()
  let matches = cmd.parse(argv=args) catch {
    e => raise @ir.CliError::InvalidArgs(e.to_string())
  }

  let output_kind : @ir.OutputKind = if matches.flags.contains("relocatable") {
    Relocatable
  } else if matches.flags.contains("executable") {
    ExecutablePie
  } else if matches.flags.contains("shared") ||
    matches.flags.contains("dynamic-library") {
    SharedLibrary
  } else if matches.flags.contains("efi-application") {
    EfiApplication
  } else if matches.flags.contains("efi-boot-driver") {
    EfiBootDriver
  } else if matches.flags.contains("efi-runtime-driver") {
    EfiRuntimeDriver
  } else {
    Relocatable
  }

  let section_align = match matches.values.get("alignment") {
    Some([s]) => parse_alignment(s)
    _ => 4096
  }

  let start_address = match matches.values.get("start-address") {
    Some([s]) => parse_uint64(s)
    _ => 0
  }

  let linker_heap_size = parse_uint64_option(
    matches.values.get("linker-heap-size"),
  )
  let linker_block_size = parse_uint64_option(
    matches.values.get("linker-block-size"),
  )
  let linker_block_power = parse_uint_option(
    matches.values.get("linker-block-power"),
  )
  let linker_block_level = parse_uint_option(
    matches.values.get("linker-block-level"),
  )

  let input_files : Array[String] = []
  for input in matches.values.get("inputs") {
    input_files.append(input)
  }
  for path in matches.values.get("input-path").unwrap_or([]) {
    append_input_path_matches(input_files, path, false)
  }
  for path in matches.values.get("input-path-with-subdirectory").unwrap_or([]) {
    append_input_path_matches(input_files, path, true)
  }

  let dynamic_libs : Array[String] = []
  for lib_name in matches.values.get("include-dynamic-library").unwrap_or([]) {
    append_unique(dynamic_libs, lib_name)
  }
  for path in matches.values.get("include-dynamic-library-path").unwrap_or([]) {
    append_dynamic_lib_path_matches(dynamic_libs, path, false)
  }
  for
    path in matches.values
    .get("include-dynamic-library-path-with-subdirectory")
    .unwrap_or([]) {
    append_dynamic_lib_path_matches(dynamic_libs, path, true)
  }

  let dynamic_linker = match matches.values.get("dynamic-linker") {
    Some([ld, ..]) => Some(ld)
    _ =>
      match matches.values.get("dynamic-linker-path") {
        Some([ld, ..]) => Some(ld)
        _ => None
      }
  }

  {
    output: matches.values.get_or_default("output", []).get(0).unwrap_or(""),
    output_kind,
    entry: matches.values.get_or_default("entry", []).get(0).unwrap_or(""),
    signature: matches.values.get_or_default("signature", []).get(0),
    input_files,
    dynamic_libs,
    dynamic_linker,
    strip_symbols: matches.flags.contains("strip-symbols") ||
    matches.flags.contains("no-symbol-table"),
    strip_debug: matches.flags.contains("strip-debug") ||
    matches.flags.contains("no-debug-frame"),
    no_default_lib: matches.flags.contains("no-default-lib"),
    smart_linking: matches.flags.contains("smart-linking"),
    linker_heap_no_smart: matches.flags.contains("linker-heap-no-smart"),
    linker_heap_size,
    linker_block_size,
    linker_block_power,
    linker_block_level,
    section_align,
    start_address,
    verbose: matches.flags.contains("verbose"),
  }
}

///|
/// Parse alignment value
fn parse_alignment(s : String) -> UInt {
  match s {
    "page" => 4096
    "largepage" => 65536
    _ => @string.parse_uint(s) catch { _ => 4096 }
  }
}

///|
/// Parse uint64 value
fn parse_uint64(s : String) -> UInt64 {
  @string.parse_uint64(s) catch {
    _ => 0
  }
}

///|
fn parse_uint(s : String) -> UInt {
  @string.parse_uint(s) catch {
    _ => 0
  }
}

///|
fn parse_uint64_option(values : Array[String]?) -> UInt64? {
  match values {
    Some([s, ..]) => Some(s |> parse_uint64)
    _ => None
  }
}

///|
fn parse_uint_option(values : Array[String]?) -> UInt? {
  match values {
    Some([s, ..]) => Some(s |> parse_uint)
    _ => None
  }
}

///|
fn append_unique(items : Array[String], value : String) -> Unit {
  if !items.contains(value) {
    items.push(value)
  }
}

///|
fn has_any_suffix(name : String, suffixes : Array[String]) -> Bool {
  suffixes.iter().any(suffix => name.has_suffix(suffix))
}

///|
fn collect_paths_from_path(
  out : Array[String],
  path : String,
  suffixes : Array[String],
  recursive : Bool,
) -> Unit raise @ir.CliError {
  let is_file = @fs.is_file(path) catch {
    @fs.IOError(msg) => raise @ir.InvalidArgs("cannot access \{path}: \{msg}")
  }

  if is_file {
    if has_any_suffix(path, suffixes) {
      append_unique(out, path)
    }
    return
  }

  let entries = @fs.read_dir(path) catch {
    @fs.IOError(msg) =>
      raise @ir.InvalidArgs(
        "input path is not file or directory: \{path}: \{msg}",
      )
  }

  for entry in entries {
    let child = "\{path}/\{entry}"
    let child_is_file = @fs.is_file(child) catch { @fs.IOError(_) => false }
    if child_is_file {
      if has_any_suffix(entry, suffixes) {
        append_unique(out, child)
      }
      continue
    }
    if recursive {
      collect_paths_from_path(out, child, suffixes, true) catch {
        @ir.InvalidArgs(_) => ()
        @ir.MissingValue(_) => ()
        @ir.UnsupportedFlag(_) => ()
      }
    }
  }
}

///|
fn append_input_path_matches(
  input_files : Array[String],
  path : String,
  recursive : Bool,
) -> Unit raise @ir.CliError {
  collect_paths_from_path(input_files, path, [".o", ".a", ".ar"], recursive)
}

///|
fn append_dynamic_lib_path_matches(
  dynamic_libs : Array[String],
  path : String,
  recursive : Bool,
) -> Unit raise @ir.CliError {
  let full_paths : Array[String] = []
  collect_paths_from_path(full_paths, path, [".so"], recursive)
  for full in full_paths {
    append_unique(dynamic_libs, full)
  }
}
