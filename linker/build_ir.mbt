///| Build IR from input objects

///|
/// Convert ELF machine type to architecture
fn machine_to_arch(e_machine : UInt16) -> @ir.Arch {
  match e_machine {
    183 => @ir.AARCH64 // EM_AARCH64
    243 => @ir.RISCV64 // EM_RISCV
    258 => @ir.LOONGARCH64 // EM_LOONGARCH
    _ => @ir.X86_64
  } // EM_X86_64 = 62, default
}

///|
/// Convert symbol binding from ELF to IR
fn convert_binding(st_info : Byte) -> @ir.SymbolBinding {
  let binding = st_info >> 4
  match binding {
    0 => @ir.Local
    1 => @ir.Global
    _ => @ir.Weak
  } // STB_WEAK = 2
}

///|
/// Convert symbol type from ELF to IR
fn convert_symbol_type(st_info : Byte) -> @ir.SymbolType {
  let ty = st_info & 0xf
  match ty {
    0 => @ir.NoType // STT_NOTYPE
    1 => @ir.Object // STT_OBJECT
    2 => @ir.Func // STT_FUNC
    3 => @ir.Section // STT_SECTION
    4 => @ir.File // STT_FILE
    6 => @ir.Tls // STT_TLS
    _ => @ir.NoType
  }
}

///|
/// Convert symbol visibility from ELF to IR
fn convert_visibility(st_other : Byte) -> @ir.Visibility {
  let vis = st_other & 0x3
  match vis {
    0 => @ir.Default
    1 => @ir.Internal
    2 => @ir.Hidden
    _ => @ir.Protected
  } // STV_PROTECTED = 3
}

///|
/// Convert parsed section to IR section record
fn convert_section(sec : @read.ParsedSection, _sec_idx : Int) -> @ir.SectionRec {
  {
    name: sec.name,
    name_hash: sec.name.hash().to_uint64(),
    ty: sec.sh_type,
    flags: sec.sh_flags,
    align: sec.sh_addralign,
    data: sec.data,
    info: sec.sh_link,
    link: sec.sh_info,
  }
}

///|
/// Convert parsed symbol to IR symbol record
fn convert_symbol(sym : @read.ParsedSymbol, _sym_idx : Int) -> @ir.SymbolRec {
  {
    name: sym.name,
    name_hash: sym.name.hash().to_uint64(),
    binding: convert_binding(sym.st_info),
    ty: convert_symbol_type(sym.st_info),
    vis: convert_visibility(sym.st_other),
    sec_index: sym.st_shndx.to_int(),
    value: sym.st_value,
    size: sym.st_size,
  }
}

///|
/// Convert parsed relocation to IR relocation record
fn convert_relocation(
  reloc : @read.ParsedRelocation,
  _sections : Array[@read.ParsedSection],
) -> @ir.RelocRec {
  // Extract symbol index from r_info (upper 32 bits)
  let sym_idx = (reloc.r_info >> 32).to_int()
  {
    sec_index: 0, // Will be resolved later
    offset: reloc.r_offset,
    rel_type: (reloc.r_info & 0xffffffff).to_uint(),
    sym_index: sym_idx,
    addend: reloc.r_addend,
    has_addend: reloc.has_addend,
  }
}

///|
/// Convert parsed object to IR input object
pub fn from_parsed_object(parsed : @read.ParsedObject) -> @ir.InputObject {
  let sections = parsed.sections.mapi((idx, sec) => convert_section(sec, idx))
  let symbols = parsed.symbols.mapi((idx, sym) => convert_symbol(sym, idx))
  let relocs = parsed.relocations.mapi((_idx, reloc) => {
    convert_relocation(reloc, parsed.sections)
  })
  {
    path: parsed.path,
    raw: parsed.raw,
    arch: machine_to_arch(parsed.e_machine),
    bitness: @ir.ELF64,
    sections,
    symbols,
    relocs,
  }
}

///|
/// Build intermediate representation from inputs
pub fn build_ir(
  input_objects : Array[@ir.InputObject],
  _opts : @ir.LinkOptions,
) -> @ir.LinkIr {
  // Determine architecture from first object (or use default)
  let arch = if input_objects.length() > 0 {
    input_objects[0].arch
  } else {
    @ir.X86_64
  }

  // Build initial IR
  {
    arch,
    bitness: @ir.ELF64,
    input_objects,
    merged_sections: [],
    merged_symbols: [],
    pending_relocs: [],
  }
}
