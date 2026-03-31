///| Snapshot testing utilities

///|
const SNAPSHOT_EXT : String = ".snap"

///|
/// Create snapshot from ELF binary metadata
pub fn snapshot_elf_summary(bytes : Bytes) -> String {
  let parsed = @read.parse_object(bytes, "<snapshot>") catch {
    _ => return "invalid-elf"
  }

  let out = StringBuilder::new()
  out.write_string("elf64")
  out.write_string("\ntype=")
  out.write_string(parsed.e_type.to_string())
  out.write_string(" machine=")
  out.write_string(parsed.e_machine.to_string())

  out.write_string("\n[sections]")
  for sec in parsed.sections {
    out.write_string("\n")
    out.write_string(sec.name)
    out.write_string(" type=")
    out.write_string(sec.sh_type.to_string())
    out.write_string(" flags=")
    out.write_string(sec.sh_flags.to_string())
    out.write_string(" size=")
    out.write_string(sec.sh_size.to_string())
  }

  out.write_string("\n[symbols]")
  for sym in parsed.symbols {
    out.write_string("\n")
    out.write_string(sym.name)
    out.write_string(" info=")
    out.write_string(sym.st_info.to_string())
    out.write_string(" shndx=")
    out.write_string(sym.st_shndx.to_string())
    out.write_string(" value=")
    out.write_string(sym.st_value.to_string())
    out.write_string(" size=")
    out.write_string(sym.st_size.to_string())
  }

  out.write_string("\n[relocations]")
  for reloc in parsed.relocations {
    out.write_string("\n")
    out.write_string(reloc.section_name)
    out.write_string(" off=")
    out.write_string(reloc.r_offset.to_string())
    out.write_string(" info=")
    out.write_string(reloc.r_info.to_string())
    out.write_string(" addend=")
    out.write_string(reloc.r_addend.to_string())
    out.write_string(" has_addend=")
    out.write_string(reloc.has_addend.to_string())
  }
  out.to_string()
}

///|
/// Compare against stored snapshot
pub fn assert_snapshot(name : String, actual : String) -> Bool {
  let path = "testkit/fixtures/\{name}\{SNAPSHOT_EXT}"
  let expected = @fs.read_file_to_string(path) catch {
    @fs.IOError(_) => return false
  }
  expected == actual
}
