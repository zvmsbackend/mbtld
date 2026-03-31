///|
pub struct InputObject {
  path : String
  data : Bytes
} derive(Show)

///|
pub struct ParsedObject {
  path : String
  raw : Bytes
  e_type : UInt16
  e_machine : UInt16
  sections : Array[ParsedSection]
  symbols : Array[ParsedSymbol]
  relocations : Array[ParsedRelocation]
} derive(Show)

///|
pub struct ParsedSection {
  name : String
  name_offset : UInt
  sh_type : UInt
  sh_flags : UInt64
  sh_addr : UInt64
  sh_offset : UInt64
  sh_size : UInt64
  sh_link : UInt
  sh_info : UInt
  sh_addralign : UInt64
  sh_entsize : UInt64
  data : Bytes
} derive(Show)

///|
pub struct ParsedSymbol {
  name : String
  name_offset : UInt
  st_info : Byte
  st_other : Byte
  st_shndx : UInt16
  st_value : UInt64
  st_size : UInt64
} derive(Show)

///|
pub struct ParsedRelocation {
  section_name : String
  r_offset : UInt64
  r_info : UInt64
  r_addend : Int64
  has_addend : Bool
} derive(Show)

///|
/// Archive magic
pub const AR_MAGIC : String = "!<arch>"

///|
pub struct ArchiveMember {
  name : String
  data : Bytes
} derive(Show)

///|
/// Read and parse an ELF object file
pub fn read_object(path : String) -> ParsedObject raise {
  let data = @fs.read_file_to_bytes(path)
  ignore(InputObject::{ path, data })
  parse_object(data, path)
}

///|
/// Parse an ELF object from bytes
pub fn parse_object(data : Bytes, path : String) -> ParsedObject raise ElfError {
  let cursor = @base.IoCursor::new(data)
  let header = parse_elf_header(cursor, path)
  let sections = parse_sections(cursor, header, data)
  let named_sections = resolve_section_names(sections, data, header.e_shstrndx)
  let symbols = parse_symbols(named_sections, data)
  let relocations = parse_relocations(named_sections, data)
  {
    path,
    raw: data,
    e_type: header.e_type,
    e_machine: header.e_machine,
    sections: named_sections,
    symbols,
    relocations,
  }
}

///|
/// Parse ELF64 header
fn parse_elf_header(
  cursor : @base.IoCursor,
  path : String,
) -> @model.Elf64Ehdr raise ElfError {
  if cursor.remaining() < @model.ELF64_EHDR_SIZE {
    raise TruncatedFile("file too small: \{path}")
  }
  let e_ident = cursor
    .read_bytes(16)
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()

  // Validate magic
  if e_ident[0] != @model.ELFMAG0 ||
    e_ident[1] != @model.ELFMAG1 ||
    e_ident[2] != @model.ELFMAG2 ||
    e_ident[3] != @model.ELFMAG3 {
    raise BadSignature("invalid ELF magic in \{path}")
  }

  // Validate class (only ELF64 for now)
  let e_class = e_ident[@model.EI_CLASS]
  if e_class != @model.ELFCLASS64 {
    raise UnsupportedClass(
      "only ELF64 supported, got class \{e_class} in \{path}",
    )
  }

  // Validate data encoding (little-endian)
  let e_data = e_ident[@model.EI_DATA]
  if e_data != @model.ELFDATA2LSB {
    raise BadSignature("only little-endian supported, got encoding \{e_data}")
  }

  let e_type = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  // catch { Err(msg) => raise TruncatedFile(msg) }
  let e_machine = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_version = cursor
    .read_u32_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_entry = cursor
    .read_u64_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_phoff = cursor
    .read_u64_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_shoff = cursor
    .read_u64_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_flags = cursor
    .read_u32_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_ehsize = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_phentsize = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_phnum = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_shentsize = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_shnum = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()
  let e_shstrndx = cursor
    .read_u16_le()
    .map_err(msg => TruncatedFile(msg))
    .unwrap_or_error()

  // Validate object type
  if e_type != @model.ET_REL {
    raise InvalidObjectType(
      "expected relocatable (ET_REL), got \{e_type} in \{path}",
    )
  }

  if e_machine != @model.EM_X86_64 &&
    e_machine != @model.EM_AARCH64 &&
    e_machine != @model.EM_RISCV &&
    e_machine != @model.EM_LOONGARCH {
    raise UnsupportedMachine("unsupported machine \{e_machine} in \{path}")
  }

  @model.Elf64Ehdr::{
    e_ident,
    e_type,
    e_machine,
    e_version,
    e_entry,
    e_phoff,
    e_shoff,
    e_flags,
    e_ehsize,
    e_phentsize,
    e_phnum,
    e_shentsize,
    e_shnum,
    e_shstrndx,
  }
}

///|
/// Parse section headers and load section data
fn parse_sections(
  cursor : @base.IoCursor,
  header : @model.Elf64Ehdr,
  data : Bytes,
) -> Array[ParsedSection] raise ElfError {
  if header.e_shoff == 0 || header.e_shnum == 0 {
    return []
  }
  cursor.skip(header.e_shoff.to_int() - @model.ELF64_EHDR_SIZE)

  let sections : Array[ParsedSection] = []
  for _ in 0..<header.e_shnum.to_int() {
    if cursor.remaining() < @model.ELF64_SHDR_SIZE {
      raise TruncatedFile("truncated section header")
    }
    let sec = read_section_header(cursor, data)
    sections.push(sec)
  }
  sections
}

///|
/// Read a single section header
fn read_section_header(
  cursor : @base.IoCursor,
  data : Bytes,
) -> ParsedSection raise ElfError {
  let sh_name = cursor
    .read_u32_le()
    .map_err(msg => InvalidSection("cannot read sh_name: \{msg}"))
    .unwrap_or_error()
  let sh_type = cursor
    .read_u32_le()
    .map_err(msg => InvalidSection("cannot read sh_type: \{msg}"))
    .unwrap_or_error()
  let sh_flags = cursor
    .read_u64_le()
    .map_err(msg => InvalidSection("cannot read sh_flags: \{msg}"))
    .unwrap_or_error()
  let sh_addr = cursor
    .read_u64_le()
    .map_err(msg => InvalidSection("cannot read sh_addr: \{msg}"))
    .unwrap_or_error()
  let sh_offset = cursor
    .read_u64_le()
    .map_err(msg => InvalidSection("cannot read sh_offset: \{msg}"))
    .unwrap_or_error()
  let sh_size = cursor
    .read_u64_le()
    .map_err(msg => InvalidSection("cannot read sh_size: \{msg}"))
    .unwrap_or_error()
  let sh_link = cursor
    .read_u32_le()
    .map_err(msg => InvalidSection("cannot read sh_link: \{msg}"))
    .unwrap_or_error()
  let sh_info = cursor
    .read_u32_le()
    .map_err(msg => InvalidSection("cannot read sh_info: \{msg}"))
    .unwrap_or_error()
  let sh_addralign = cursor
    .read_u64_le()
    .map_err(msg => InvalidSection("cannot read sh_addralign: \{msg}"))
    .unwrap_or_error()
  let sh_entsize = cursor
    .read_u64_le()
    .map_err(msg => InvalidSection("cannot read sh_entsize: \{msg}"))
    .unwrap_or_error()

  // Load section data
  let sec_data = if sh_type == @model.SHT_NOBITS || sh_size == 0 {
    b""
  } else if sh_offset.to_int() + sh_size.to_int() > data.length() {
    b""
  } else {
    data[sh_offset.to_int():(sh_offset + sh_size).to_int()].to_bytes()
  }

  {
    name: "",
    name_offset: sh_name,
    sh_type,
    sh_flags,
    sh_addr,
    sh_offset,
    sh_size,
    sh_link,
    sh_info,
    sh_addralign,
    sh_entsize,
    data: sec_data,
  }
}

///|
/// Resolve section names from string table
fn resolve_section_names(
  sections : Array[ParsedSection],
  data : Bytes,
  shstrndx : UInt16,
) -> Array[ParsedSection] {
  if shstrndx.to_int() >= sections.length() {
    return sections
  }
  let shstrtab_sec = sections[shstrndx.to_int()]
  if shstrtab_sec.sh_offset.to_int() + shstrtab_sec.sh_size.to_int() >
    data.length() {
    return sections
  }
  let shstrtab = data[shstrtab_sec.sh_offset.to_int():(shstrtab_sec.sh_offset +
  shstrtab_sec.sh_size).to_int()].to_bytes()
  sections.map(fn(sec : ParsedSection) -> ParsedSection {
    let name = read_cstring(shstrtab, sec.name_offset)
    { ..sec, name, }
  })
}

///|
/// Parse symbol table
fn parse_symbols(
  sections : Array[ParsedSection],
  data : Bytes,
) -> Array[ParsedSymbol] raise ElfError {
  // Find .symtab section
  let symtab_idx = sections.search_by(sec => sec.sh_type == @model.SHT_SYMTAB)
  guard symtab_idx is Some(symtab_idx) else { return [] }
  let symtab_sec = sections[symtab_idx]
  if symtab_sec.sh_link.reinterpret_as_int() >= sections.length() {
    raise InvalidSymbol("invalid sh_link for symtab")
  }
  let strtab_sec = sections[symtab_sec.sh_link.reinterpret_as_int()]
  if strtab_sec.sh_offset.to_int() + strtab_sec.sh_size.to_int() > data.length() {
    raise TruncatedFile("truncated strtab")
  }
  let strtab = data[strtab_sec.sh_offset.to_int():(strtab_sec.sh_offset +
  strtab_sec.sh_size).to_int()].to_bytes()

  let sym_off = symtab_sec.sh_offset.to_int()
  let sym_end = (symtab_sec.sh_offset + symtab_sec.sh_size).to_int()
  let sym_size = @model.ELF64_SYM_SIZE

  let symbols : Array[ParsedSymbol] = []
  for pos = sym_off; pos + sym_size <= sym_end; pos = pos + sym_size {
    let st_name = @base.read_u32_le(data, pos)
    let st_info = if pos + 4 < data.length() { data[pos + 4] } else { 0 }
    let st_other = if pos + 5 < data.length() { data[pos + 5] } else { 0 }
    let st_shndx = @base.read_u16_le(data, pos + 6)
    let st_value = @base.read_u64_le(data, pos + 8)
    let st_size = @base.read_u64_le(data, pos + 16)

    let name = read_cstring(strtab, st_name)
    symbols.push({
      name,
      name_offset: st_name,
      st_info,
      st_other,
      st_shndx,
      st_value,
      st_size,
    })
  }
  symbols
}

///|
/// Parse relocations
fn parse_relocations(
  sections : Array[ParsedSection],
  data : Bytes,
) -> Array[ParsedRelocation] raise ElfError {
  let mut relocations : Array[ParsedRelocation] = []
  for sec in sections {
    if sec.sh_type == @model.SHT_RELA {
      if sec.sh_size.to_int() % @model.ELF64_RELA_SIZE != 0 {
        raise InvalidRelocation("SHT_RELA section size is not entry-aligned")
      }
      let relas = parse_rela_section(sec, data)
      relocations = relocations + relas
    } else if sec.sh_type == @model.SHT_REL {
      if sec.sh_size.to_int() % @model.ELF64_REL_SIZE != 0 {
        raise InvalidRelocation("SHT_REL section size is not entry-aligned")
      }
      let rels = parse_rel_section(sec, data)
      relocations = relocations + rels
    }
  }
  relocations
}

///|
/// Parse RELA section
fn parse_rela_section(
  sec : ParsedSection,
  data : Bytes,
) -> Array[ParsedRelocation] {
  let relocations : Array[ParsedRelocation] = []
  let off = sec.sh_offset.to_int()
  let end = (sec.sh_offset + sec.sh_size).to_int()
  let rela_size = @model.ELF64_RELA_SIZE

  for pos = off; pos + rela_size <= end; pos = pos + rela_size {
    let r_offset = @base.read_u64_le(data, pos)
    let r_info = @base.read_u64_le(data, pos + 8)
    let r_addend = @base.read_i64_le(data, pos + 16)
    relocations.push({
      section_name: sec.name,
      r_offset,
      r_info,
      r_addend,
      has_addend: true,
    })
  }
  relocations
}

///|
/// Parse REL section
fn parse_rel_section(
  sec : ParsedSection,
  data : Bytes,
) -> Array[ParsedRelocation] {
  let relocations : Array[ParsedRelocation] = []
  let off = sec.sh_offset.to_int()
  let end = (sec.sh_offset + sec.sh_size).to_int()
  let rel_size = @model.ELF64_REL_SIZE

  for pos = off; pos + rel_size <= end; pos = pos + rel_size {
    let r_offset = @base.read_u64_le(data, pos)
    let r_info = @base.read_u64_le(data, pos + 8)
    relocations.push({
      section_name: sec.name,
      r_offset,
      r_info,
      r_addend: 0,
      has_addend: false,
    })
  }
  relocations
}
