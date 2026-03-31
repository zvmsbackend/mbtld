///| Write relocatable ELF output

///|
fn rr_align_up_int(value : Int, align : UInt64) -> Int {
  let a = align.to_int()
  if a <= 1 {
    return value
  }
  (value + a - 1) / a * a
}

///|
fn rr_machine_from_arch(arch : @ir.Arch) -> UInt16 {
  match arch {
    X86_64 => @model.EM_X86_64
    AARCH64 => @model.EM_AARCH64
    RISCV64 => @model.EM_RISCV
    LOONGARCH64 => @model.EM_LOONGARCH
  }
}

///|
fn rr_infer_sh_type(name : String) -> UInt {
  match name {
    ".bss" | ".tbss" => @model.SHT_NOBITS
    ".init_array" => @model.SHT_INIT_ARRAY
    ".fini_array" => @model.SHT_FINI_ARRAY
    ".preinit_array" => @model.SHT_PREINIT_ARRAY
    _ => @model.SHT_PROGBITS
  }
}

///|
fn rr_infer_sh_flags(name : String) -> UInt64 {
  let flags = match name {
    ".text" | ".init" | ".fini" => @model.SHF_ALLOC | @model.SHF_EXECINSTR
    ".rodata" => @model.SHF_ALLOC
    _ => @model.SHF_ALLOC | @model.SHF_WRITE
  }

  if name.has_prefix(".t") {
    flags | @model.SHF_TLS
  } else {
    flags
  }
}

///|
priv struct RrShdr {
  sh_name : UInt
  sh_type : UInt
  sh_flags : UInt64
  sh_addr : UInt64
  sh_offset : UInt64
  sh_size : UInt64
  sh_link : UInt
  sh_info : UInt
  sh_addralign : UInt64
  sh_entsize : UInt64
} derive(Default)

///|
fn rr_push_u32_le(out : Array[Byte], v : UInt) -> Unit {
  out.push((v & 0xffU).to_byte())
  out.push(((v >> 8) & 0xffU).to_byte())
  out.push(((v >> 16) & 0xffU).to_byte())
  out.push(((v >> 24) & 0xffU).to_byte())
}

///|
fn rr_push_u64_le(out : Array[Byte], v : UInt64) -> Unit {
  out.push((v & 0xffUL).to_byte())
  out.push(((v >> 8) & 0xffUL).to_byte())
  out.push(((v >> 16) & 0xffUL).to_byte())
  out.push(((v >> 24) & 0xffUL).to_byte())
  out.push(((v >> 32) & 0xffUL).to_byte())
  out.push(((v >> 40) & 0xffUL).to_byte())
  out.push(((v >> 48) & 0xffUL).to_byte())
  out.push(((v >> 56) & 0xffUL).to_byte())
}

///|
fn rr_write_u16_le(out : Array[Byte], offset : Int, v : UInt16) -> Unit {
  let vv = v.to_uint()
  out[offset] = (vv & 0xffU).to_byte()
  out[offset + 1] = ((vv >> 8) & 0xffU).to_byte()
}

///|
fn rr_write_u32_le(out : Array[Byte], offset : Int, v : UInt) -> Unit {
  out[offset] = (v & 0xffU).to_byte()
  out[offset + 1] = ((v >> 8) & 0xffU).to_byte()
  out[offset + 2] = ((v >> 16) & 0xffU).to_byte()
  out[offset + 3] = ((v >> 24) & 0xffU).to_byte()
}

///|
fn rr_write_u64_le(out : Array[Byte], offset : Int, v : UInt64) -> Unit {
  out[offset] = (v & 0xffUL).to_byte()
  out[offset + 1] = ((v >> 8) & 0xffUL).to_byte()
  out[offset + 2] = ((v >> 16) & 0xffUL).to_byte()
  out[offset + 3] = ((v >> 24) & 0xffUL).to_byte()
  out[offset + 4] = ((v >> 32) & 0xffUL).to_byte()
  out[offset + 5] = ((v >> 40) & 0xffUL).to_byte()
  out[offset + 6] = ((v >> 48) & 0xffUL).to_byte()
  out[offset + 7] = ((v >> 56) & 0xffUL).to_byte()
}

///|
priv struct RrSymtabBuild {
  symtab : Bytes
  strtab : Bytes
  local_count : Int
  sym_index_map : Array[Int]
}

///|
priv struct RrRelocSection {
  name : String
  out_sec : Int
  bytes : Bytes
  has_addend : Bool
}

///|
fn rr_symbol_binding_to_elf(binding : @ir.SymbolBinding) -> Byte {
  match binding {
    Local => @model.STB_LOCAL
    Global => @model.STB_GLOBAL
    Weak => @model.STB_WEAK
  }
}

///|
fn rr_symbol_type_to_elf(ty : @ir.SymbolType) -> Byte {
  match ty {
    NoType => @model.STT_NOTYPE
    Object => @model.STT_OBJECT
    Func => @model.STT_FUNC
    Section => @model.STT_SECTION
    File => @model.STT_FILE
    Tls => @model.STT_TLS
  }
}

///|
fn rr_visibility_to_elf(vis : @ir.Visibility) -> Byte {
  match vis {
    Default => @model.STV_DEFAULT
    Internal => @model.STV_INTERNAL
    Hidden => @model.STV_HIDDEN
    Protected => @model.STV_PROTECTED
  }
}

///|
fn rr_append_cstr_with_offset(arr : Array[Byte], s : String) -> UInt {
  let off = arr.length().reinterpret_as_uint()
  for ch in s {
    arr.push(Char::to_int(ch).to_byte())
  }
  arr.push(0)
  off
}

///|
fn rr_build_symtab_and_strtab(ir : @ir.LinkIr) -> RrSymtabBuild {
  let ordered : Array[(Int, @ir.MergedSymbol)] = []
  let sym_index_map = [0].repeat(ir.merged_symbols.length())
  let mut local_count = 0
  for i, sym in ir.merged_symbols {
    if sym.binding is Local {
      ordered.push((i, sym))
      local_count += 1
    }
  }
  for i, sym in ir.merged_symbols {
    if !(sym.binding is Local) {
      ordered.push((i, sym))
    }
  }

  let strtab : Array[Byte] = [0]
  let st_name_offsets : Array[UInt] = []
  for entry in ordered {
    st_name_offsets.push(rr_append_cstr_with_offset(strtab, entry.1.name))
  }

  let symtab : Array[Byte] = []
  for _ in 0..<@model.ELF64_SYM_SIZE {
    symtab.push(0)
  }

  for i, entry in ordered {
    let (orig_idx, sym) = entry
    sym_index_map[orig_idx] = i + 1
    let st_name = st_name_offsets[i]
    let st_info = ((rr_symbol_binding_to_elf(sym.binding).to_int() << 4) |
    rr_symbol_type_to_elf(sym.ty).to_int()).to_byte()
    let st_other = rr_visibility_to_elf(sym.vis)
    let st_shndx = if sym.output_sec >= 0 {
      (sym.output_sec + 1).to_uint16()
    } else {
      @model.SHN_UNDEF
    }
    let st_value = if sym.output_sec >= 0 { sym.output_value } else { 0UL }
    let st_size = 0UL

    rr_push_u32_le(symtab, st_name)
    symtab.push(st_info)
    symtab.push(st_other)
    symtab.push((st_shndx.to_uint() & 0xffU).to_byte())
    symtab.push(((st_shndx.to_uint() >> 8) & 0xffU).to_byte())
    rr_push_u64_le(symtab, st_value)
    rr_push_u64_le(symtab, st_size)
  }

  {
    symtab: Bytes::from_array(symtab),
    strtab: Bytes::from_array(strtab),
    local_count,
    sym_index_map,
  }
}

///|
fn rr_build_reloc_sections(
  ir : @ir.LinkIr,
  sym_index_map : Array[Int],
) -> Array[RrRelocSection] {
  let relocs : Array[RrRelocSection] = []
  for out_sec, sec in ir.merged_sections {
    let out_name = sec.output_name
    let out_rela : Array[Byte] = []
    let out_rel : Array[Byte] = []
    let mut has_rela = false
    let mut has_rel = false

    for reloc in ir.pending_relocs {
      if reloc.out_sec != out_sec {
        continue
      }

      let sym_idx = if reloc.target_sym >= 0 &&
        reloc.target_sym < sym_index_map.length() {
        sym_index_map[reloc.target_sym].to_uint64()
      } else {
        0UL
      }
      let r_info = (sym_idx << 32) | reloc.rel_type.to_uint64()

      if reloc.has_addend {
        has_rela = true
        rr_push_u64_le(out_rela, reloc.patch_off)
        rr_push_u64_le(out_rela, r_info)
        rr_push_u64_le(out_rela, reloc.addend.reinterpret_as_uint64())
      } else {
        has_rel = true
        rr_push_u64_le(out_rel, reloc.patch_off)
        rr_push_u64_le(out_rel, r_info)
      }
    }

    if has_rela {
      relocs.push({
        name: ".rela\{out_name}",
        out_sec,
        bytes: Bytes::from_array(out_rela),
        has_addend: true,
      })
    }
    if has_rel {
      relocs.push({
        name: ".rel\{out_name}",
        out_sec,
        bytes: Bytes::from_array(out_rel),
        has_addend: false,
      })
    }
  }
  relocs
}

///|
fn rr_build_elf64_relocatable(ir : @ir.LinkIr) -> Bytes {
  let sym_build = rr_build_symtab_and_strtab(ir)
  let reloc_sections = rr_build_reloc_sections(ir, sym_build.sym_index_map)
  let section_names : Array[String] = ir.merged_sections.map(sec => {
    sec.output_name
  })
  for relsec in reloc_sections {
    section_names.push(relsec.name)
  }
  section_names.push(".symtab")
  section_names.push(".strtab")
  section_names.push(".shstrtab")

  let sh_name_offsets : Array[UInt] = []
  let shstr : Array[Byte] = [0]
  for name in section_names {
    sh_name_offsets.push(shstr.length().reinterpret_as_uint())
    for ch in name {
      shstr.push(Char::to_int(ch).to_byte())
    }
    shstr.push(0)
  }
  let shstr_bytes = Bytes::from_array(shstr)

  let shdrs : Array[RrShdr] = [RrShdr::default()]

  let file = [b'\x00'].repeat(@model.ELF64_EHDR_SIZE)

  let mut cursor = @model.ELF64_EHDR_SIZE
  for i, sec in ir.merged_sections {
    let sec_ty = rr_infer_sh_type(sec.output_name)
    let sec_flags = rr_infer_sh_flags(sec.output_name)
    let sec_align = if sec.align == 0UL { 1UL } else { sec.align }

    let mut sec_off = 0UL
    if sec_ty != @model.SHT_NOBITS {
      cursor = rr_align_up_int(cursor, sec_align)
      sec_off = cursor.to_uint64()
      for _ in file.length()..<cursor {
        file.push(0)
      }
      for b in sec.bytes {
        file.push(b)
      }
      cursor += sec.bytes.length()
    }

    shdrs.push({
      sh_name: sh_name_offsets[i],
      sh_type: sec_ty,
      sh_flags: sec_flags,
      sh_addr: 0,
      sh_offset: sec_off,
      sh_size: sec.bytes.length().to_uint64(),
      sh_link: 0,
      sh_info: 0,
      sh_addralign: sec_align,
      sh_entsize: 0,
    })
  }

  let symtab_idx = 1 + ir.merged_sections.length() + reloc_sections.length()
  let strtab_idx = symtab_idx + 1
  let rel_name_base = ir.merged_sections.length()

  for i, relsec in reloc_sections {
    cursor = rr_align_up_int(cursor, 8UL)
    let rel_off = cursor.to_uint64()
    for _ in file.length()..<cursor {
      file.push(0)
    }
    for b in relsec.bytes {
      file.push(b)
    }
    cursor += relsec.bytes.length()

    shdrs.push({
      sh_name: sh_name_offsets[rel_name_base + i],
      sh_type: if relsec.has_addend {
        @model.SHT_RELA
      } else {
        @model.SHT_REL
      },
      sh_flags: 0,
      sh_addr: 0,
      sh_offset: rel_off,
      sh_size: relsec.bytes.length().to_uint64(),
      sh_link: symtab_idx.reinterpret_as_uint(),
      sh_info: (relsec.out_sec + 1).reinterpret_as_uint(),
      sh_addralign: 8UL,
      sh_entsize: if relsec.has_addend {
        @model.ELF64_RELA_SIZE.to_uint64()
      } else {
        @model.ELF64_REL_SIZE.to_uint64()
      },
    })
  }

  cursor = rr_align_up_int(cursor, 8UL)
  let symtab_off = cursor.to_uint64()
  for _ in file.length()..<cursor {
    file.push(0)
  }
  for b in sym_build.symtab {
    file.push(b)
  }
  cursor += sym_build.symtab.length()

  let symtab_name_idx = ir.merged_sections.length() + reloc_sections.length()
  let strtab_name_idx = symtab_name_idx + 1
  let shstrtab_name_idx = strtab_name_idx + 1

  cursor = rr_align_up_int(cursor, 1UL)
  let strtab_off = cursor.to_uint64()
  for _ in file.length()..<cursor {
    file.push(0)
  }
  for b in sym_build.strtab {
    file.push(b)
  }
  cursor += sym_build.strtab.length()

  shdrs.push({
    sh_name: sh_name_offsets[symtab_name_idx],
    sh_type: @model.SHT_SYMTAB,
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: symtab_off,
    sh_size: sym_build.symtab.length().to_uint64(),
    sh_link: strtab_idx.reinterpret_as_uint(),
    sh_info: (sym_build.local_count + 1).reinterpret_as_uint(),
    sh_addralign: 8UL,
    sh_entsize: @model.ELF64_SYM_SIZE.to_uint64(),
  })

  shdrs.push({
    sh_name: sh_name_offsets[strtab_name_idx],
    sh_type: @model.SHT_STRTAB,
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: strtab_off,
    sh_size: sym_build.strtab.length().to_uint64(),
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 1,
    sh_entsize: 0,
  })

  cursor = rr_align_up_int(cursor, 1UL)
  let shstr_off = cursor.to_uint64()
  for _ in file.length()..<cursor {
    file.push(0)
  }
  for b in shstr_bytes {
    file.push(b)
  }
  cursor += shstr_bytes.length()

  shdrs.push({
    sh_name: sh_name_offsets[shstrtab_name_idx],
    sh_type: @model.SHT_STRTAB,
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: shstr_off,
    sh_size: shstr_bytes.length().to_uint64(),
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 1,
    sh_entsize: 0,
  })

  cursor = rr_align_up_int(cursor, 8UL)
  let e_shoff = cursor.to_uint64()
  for _ in file.length()..<cursor {
    file.push(0)
  }

  for sh in shdrs {
    rr_push_u32_le(file, sh.sh_name)
    rr_push_u32_le(file, sh.sh_type)
    rr_push_u64_le(file, sh.sh_flags)
    rr_push_u64_le(file, sh.sh_addr)
    rr_push_u64_le(file, sh.sh_offset)
    rr_push_u64_le(file, sh.sh_size)
    rr_push_u32_le(file, sh.sh_link)
    rr_push_u32_le(file, sh.sh_info)
    rr_push_u64_le(file, sh.sh_addralign)
    rr_push_u64_le(file, sh.sh_entsize)
  }

  // ELF ident
  file[@model.EI_MAG0] = @model.ELFMAG0
  file[@model.EI_MAG1] = @model.ELFMAG1
  file[@model.EI_MAG2] = @model.ELFMAG2
  file[@model.EI_MAG3] = @model.ELFMAG3
  file[@model.EI_CLASS] = @model.ELFCLASS64
  file[@model.EI_DATA] = @model.ELFDATA2LSB
  file[@model.EI_VERSION] = 1
  file[@model.EI_OSABI] = 0
  file[@model.EI_ABIVERSION] = 0

  rr_write_u16_le(file, 16, @model.ET_REL)
  rr_write_u16_le(file, 18, rr_machine_from_arch(ir.arch))
  rr_write_u32_le(file, 20, 1)
  rr_write_u64_le(file, 24, 0UL)
  rr_write_u64_le(file, 32, 0UL)
  rr_write_u64_le(file, 40, e_shoff)
  rr_write_u32_le(file, 48, 0)
  rr_write_u16_le(file, 52, @model.ELF64_EHDR_SIZE.to_uint16())
  rr_write_u16_le(file, 54, 0)
  rr_write_u16_le(file, 56, 0)
  rr_write_u16_le(file, 58, @model.ELF64_SHDR_SIZE.to_uint16())
  rr_write_u16_le(file, 60, shdrs.length().to_uint16())
  rr_write_u16_le(file, 62, (shdrs.length() - 1).to_uint16())

  Bytes::from_array(file)
}

///|
/// Write relocatable output
pub fn write_relocatable(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkArtifact raise @ir.WriteError {
  if ir.input_objects.length() == 0 {
    raise LayoutFailure("no input object to emit")
  }

  if ir.merged_sections.length() == 0 {
    if ir.input_objects.length() > 1 {
      raise LayoutFailure(
        "no merged output sections for multi-input relocatable build",
      )
    }
    // Keep backward compatibility for minimal single-input flow.
    return {
      bytes: ir.input_objects[0].raw,
      map_text: Some("mvp: passthrough relocatable output"),
    }
  }

  let payload = rr_build_elf64_relocatable(ir)

  {
    bytes: payload,
    map_text: Some(
      "relocatable payload from \{ir.merged_sections.length()} sections, align=\{opts.section_align}",
    ),
  }
}
