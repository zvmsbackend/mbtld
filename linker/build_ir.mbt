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
    0 => Local
    1 => Global
    _ => Weak
  } // STB_WEAK = 2
}

///|
/// Convert symbol type from ELF to IR
fn convert_symbol_type(st_info : Byte) -> @ir.SymbolType {
  let ty = st_info & 0xf
  match ty {
    0 => NoType // STT_NOTYPE
    1 => Object // STT_OBJECT
    2 => Func // STT_FUNC
    3 => Section // STT_SECTION
    4 => File // STT_FILE
    6 => Tls // STT_TLS
    _ => NoType
  }
}

///|
/// Convert symbol visibility from ELF to IR
fn convert_visibility(st_other : Byte) -> @ir.Visibility {
  let vis = st_other & 0x3
  match vis {
    0 => Default
    1 => Internal
    2 => Hidden
    _ => Protected
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
  sections : Array[@read.ParsedSection],
) -> @ir.RelocRec {
  let target_name = strip_reloc_prefix(reloc.section_name)
  let sec_index = sections
    .search_by(sec => sec.name == target_name)
    .unwrap_or(-1)

  // Extract symbol index from r_info (upper 32 bits)
  let sym_idx = (reloc.r_info >> 32).to_int()
  {
    sec_index,
    offset: reloc.r_offset,
    rel_type: (reloc.r_info & 0xffffffff).to_uint(),
    sym_index: sym_idx,
    addend: reloc.r_addend,
    has_addend: reloc.has_addend,
  }
}

///|
fn strip_reloc_prefix(name : String) -> String {
  if name.has_prefix(".rela") {
    name[5:].to_string()
  } else if name.has_prefix(".rel") {
    name[4:].to_string()
  } else {
    name
  }
}

///|
fn should_merge_section(sec : @ir.SectionRec) -> Bool {
  if sec.name == "" {
    return false
  }
  if sec.data.length() == 0 {
    return false
  }
  if sec.name is (".symtab" | ".strtab" | ".shstrtab") {
    return false
  }
  !sec.name.has_prefix(".rel")
}

///|
fn align_up_int(value : Int, align : UInt64) -> Int {
  let a = align.to_int()
  if a <= 1 {
    return value
  }
  (value + a - 1) / a * a
}

///|
fn append_with_padding(base : Bytes, pad : Int, tail : Bytes) -> Bytes {
  let out = base.to_array()
  for _ in 0..<pad {
    out.push(0)
  }
  for b in tail {
    out.push(b)
  }
  Bytes::from_array(out)
}

///|
fn normalized_symbol_name(path : String, sym : @ir.SymbolRec) -> String {
  if sym.binding is Local {
    "\{path}:\{sym.name}"
  } else {
    sym.name
  }
}

///|
fn find_merged_section_index(
  merged_sections : Array[@ir.MergedSection],
  name : String,
) -> Int {
  merged_sections.search_by(sec => sec.output_name == name).unwrap_or(-1)
}

///|
fn find_merged_symbol_index(
  merged_symbols : Array[@ir.MergedSymbol],
  name : String,
) -> Int {
  merged_symbols.search_by(sym => sym.name == name).unwrap_or(-1)
}

///|
fn section_rank(name : String) -> Int {
  @resolve.section_order(name)
}

///|
fn reorder_sections_and_remap(
  merged_sections : Array[@ir.MergedSection],
  sec_index_maps : Array[Array[Int]],
  merged_symbols : Array[@ir.MergedSymbol],
  pending_relocs : Array[@ir.PendingReloc],
) -> Unit {
  let sec_count = merged_sections.length()
  if sec_count <= 1 {
    return
  }

  let old_to_new : Array[Int] = []
  let used : Array[Bool] = []
  for _ in 0..<sec_count {
    old_to_new.push(-1)
    used.push(false)
  }

  let reordered : Array[@ir.MergedSection] = []
  for new_idx in 0..<sec_count {
    let mut best_old = -1
    let mut best_rank = 0
    for old_idx in 0..<sec_count {
      if used[old_idx] {
        continue
      }
      let rank = section_rank(merged_sections[old_idx].output_name)
      if best_old < 0 || rank < best_rank {
        best_old = old_idx
        best_rank = rank
      }
    }

    used[best_old] = true
    old_to_new[best_old] = new_idx
    let sec = merged_sections[best_old]
    reordered.push({ ..sec, output_index: new_idx })
  }

  for i in 0..<sec_count {
    merged_sections[i] = reordered[i]
  }

  for obj_idx in 0..<sec_index_maps.length() {
    let sec_map = sec_index_maps[obj_idx]
    for i in 0..<sec_map.length() {
      let old_idx = sec_map[i]
      if old_idx >= 0 {
        sec_map[i] = old_to_new[old_idx]
      }
    }
    sec_index_maps[obj_idx] = sec_map
  }

  for i in 0..<merged_symbols.length() {
    let sym = merged_symbols[i]
    if sym.output_sec >= 0 {
      merged_symbols[i] = { ..sym, output_sec: old_to_new[sym.output_sec] }
    }
  }

  for i in 0..<pending_relocs.length() {
    let reloc = pending_relocs[i]
    if reloc.out_sec >= 0 {
      pending_relocs[i] = { ..reloc, out_sec: old_to_new[reloc.out_sec] }
    }
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
    bitness: ELF64,
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
    X86_64
  }

  let merged_sections : Array[@ir.MergedSection] = []
  let sec_index_maps : Array[Array[Int]] = []
  let sec_base_maps : Array[Array[UInt64]] = []

  // Stage 1: merge allocatable payload sections by section name.
  for obj in input_objects {
    let sec_map : Array[Int] = []
    let sec_base : Array[UInt64] = []
    for _ in obj.sections {
      sec_map.push(-1)
      sec_base.push(0UL)
    }

    for sec_idx = 0; sec_idx < obj.sections.length(); sec_idx = sec_idx + 1 {
      let sec = obj.sections[sec_idx]
      if !should_merge_section(sec) {
        continue
      }

      let out_name = @resolve.get_output_section(sec.name)

      let mut out_idx = find_merged_section_index(merged_sections, out_name)
      if out_idx < 0 {
        out_idx = merged_sections.length()
        merged_sections.push({
          output_name: out_name,
          output_index: out_idx,
          align: if sec.align == 0UL {
            1UL
          } else {
            sec.align
          },
          bytes: b"",
        })
      }

      let merged = merged_sections[out_idx]
      let base_off = align_up_int(merged.bytes.length(), merged.align)
      let pad = base_off - merged.bytes.length()
      let merged_bytes = append_with_padding(merged.bytes, pad, sec.data)

      merged_sections[out_idx] = { ..merged, bytes: merged_bytes }

      sec_map[sec_idx] = out_idx
      sec_base[sec_idx] = base_off.to_uint64()
    }

    sec_index_maps.push(sec_map)
    sec_base_maps.push(sec_base)
  }

  let merged_symbols : Array[@ir.MergedSymbol] = []

  // Stage 2: map input symbols onto merged output sections/offsets.
  for obj_idx in 0..<input_objects.length() {
    let obj = input_objects[obj_idx]
    let sec_map = sec_index_maps[obj_idx]
    let sec_base = sec_base_maps[obj_idx]
    for sym in obj.symbols {
      if sym.name == "" {
        continue
      }
      let name = normalized_symbol_name(obj.path, sym)
      let out_sec = if sym.sec_index >= 0 && sym.sec_index < sec_map.length() {
        sec_map[sym.sec_index]
      } else {
        -1
      }
      let out_base = if sym.sec_index >= 0 && sym.sec_index < sec_base.length() {
        sec_base[sym.sec_index]
      } else {
        0UL
      }
      merged_symbols.push({
        name,
        output_sec: out_sec,
        output_value: out_base + sym.value,
        binding: sym.binding,
        ty: sym.ty,
        vis: sym.vis,
      })
    }
  }

  let pending_relocs : Array[@ir.PendingReloc] = []

  // Stage 3: map relocations to merged section/symbol coordinates.
  for obj_idx in 0..<input_objects.length() {
    let obj = input_objects[obj_idx]
    let sec_map = sec_index_maps[obj_idx]
    let sec_base = sec_base_maps[obj_idx]
    for rel in obj.relocs {
      if rel.sec_index < 0 || rel.sec_index >= sec_map.length() {
        continue
      }
      let out_sec = sec_map[rel.sec_index]
      if out_sec < 0 {
        continue
      }

      let patch_off = sec_base[rel.sec_index] + rel.offset
      let target_sym = if rel.sym_index >= 0 &&
        rel.sym_index < obj.symbols.length() {
        let target = obj.symbols[rel.sym_index]
        let name = normalized_symbol_name(obj.path, target)
        find_merged_symbol_index(merged_symbols, name)
      } else {
        -1
      }

      pending_relocs.push({
        out_sec,
        patch_off,
        rel_type: rel.rel_type,
        target_sym,
        addend: rel.addend,
        has_addend: rel.has_addend,
      })
    }
  }

  reorder_sections_and_remap(
    merged_sections, sec_index_maps, merged_symbols, pending_relocs,
  )

  {
    arch,
    bitness: ELF64,
    input_objects,
    merged_sections,
    merged_symbols,
    pending_relocs,
  }
}
