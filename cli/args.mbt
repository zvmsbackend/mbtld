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
        "strip-debug",
        long="strip-debug",
        about="Strip debug information",
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
        "include-dynamic-library",
        long="include-dynamic-library",
        about="Include dynamic library name (repeatable)",
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
  } else if matches.flags.contains("shared") {
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

  let input_files : Array[String] = []
  for input in matches.values.get("inputs") {
    input_files.append(input)
  }

  let dynamic_libs : Array[String] = []
  for lib_name in matches.values.get("include-dynamic-library") {
    dynamic_libs.append(lib_name)
  }

  {
    output: matches.values.get_or_default("output", []).get(0).unwrap_or(""),
    output_kind,
    entry: matches.values.get_or_default("entry", []).get(0).unwrap_or(""),
    input_files,
    dynamic_libs,
    dynamic_linker: matches.values.get_or_default("dynamic-linker", []).get(0),
    strip_symbols: matches.flags.contains("strip-symbols"),
    strip_debug: matches.flags.contains("strip-debug"),
    no_default_lib: matches.flags.contains("no-default-lib"),
    smart_linking: matches.flags.contains("smart-linking"),
    section_align,
    start_address,
    verbose: matches.flags.contains("verbose"),
  }
}

///|
/// Parse alignment value
fn parse_alignment(s : String) -> UInt {
  if s == "page" {
    4096
  } else if s == "largepage" {
    65536
  } else {
    @string.parse_uint(s[:]) catch {
      _ => 4096
    }
  }
}

///|
/// Parse uint64 value
fn parse_uint64(s : String) -> UInt64 {
  @string.parse_uint64(s[:]) catch {
    _ => 0
  }
}
