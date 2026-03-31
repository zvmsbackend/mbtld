///| Write PIE/Shared library output

///|
fn pie_align_up_int(value : Int, align : UInt64) -> Int {
  let a = align.to_int()
  if a <= 1 {
    return value
  }
  (value + a - 1) / a * a
}

///|
fn pie_machine_from_arch(arch : @ir.Arch) -> UInt16 {
  match arch {
    X86_64 => @model.EM_X86_64
    AARCH64 => @model.EM_AARCH64
    RISCV64 => @model.EM_RISCV
    LOONGARCH64 => @model.EM_LOONGARCH
  }
}

///|
fn pie_infer_sh_type(name : String) -> UInt {
  match name {
    ".dynamic" => @model.SHT_DYNAMIC
    ".hash" => @model.SHT_HASH
    ".rela.dyn" => @model.SHT_RELA
    ".dynsym" => @model.SHT_DYNSYM
    ".dynstr" => @model.SHT_STRTAB
    ".bss" | ".tbss" => @model.SHT_NOBITS
    ".init_array" => @model.SHT_INIT_ARRAY
    ".fini_array" => @model.SHT_FINI_ARRAY
    ".preinit_array" => @model.SHT_PREINIT_ARRAY
    _ => @model.SHT_PROGBITS
  }
}

///|
fn pie_infer_sh_flags(name : String) -> UInt64 {
  let flags = if name == ".text" || name == ".init" || name == ".fini" {
    @model.SHF_ALLOC | @model.SHF_EXECINSTR
  } else {
    match name {
      ".interp" => @model.SHF_ALLOC
      ".hash" => @model.SHF_ALLOC
      ".dynsym" => @model.SHF_ALLOC
      ".dynstr" => @model.SHF_ALLOC
      ".rela.dyn" => @model.SHF_ALLOC
      ".dynamic" => @model.SHF_ALLOC | @model.SHF_WRITE
      ".rodata" => @model.SHF_ALLOC
      _ => @model.SHF_ALLOC | @model.SHF_WRITE
    }
  }

  if name.has_prefix(".t") {
    flags | @model.SHF_TLS
  } else {
    flags
  }
}

///|
priv struct PieShdr {
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
fn pie_push_u32_le(out : Array[Byte], v : UInt) -> Unit {
  out.push((v & 0xffU).to_byte())
  out.push(((v >> 8) & 0xffU).to_byte())
  out.push(((v >> 16) & 0xffU).to_byte())
  out.push(((v >> 24) & 0xffU).to_byte())
}

///|
fn pie_push_u64_le(out : Array[Byte], v : UInt64) -> Unit {
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
fn pie_write_u16_le(out : Array[Byte], offset : Int, v : UInt16) -> Unit {
  let vv = v.to_uint()
  out[offset] = (vv & 0xffU).to_byte()
  out[offset + 1] = ((vv >> 8) & 0xffU).to_byte()
}

///|
fn pie_write_u32_le(out : Array[Byte], offset : Int, v : UInt) -> Unit {
  out[offset] = (v & 0xffU).to_byte()
  out[offset + 1] = ((v >> 8) & 0xffU).to_byte()
  out[offset + 2] = ((v >> 16) & 0xffU).to_byte()
  out[offset + 3] = ((v >> 24) & 0xffU).to_byte()
}

///|
fn pie_write_u64_le(out : Array[Byte], offset : Int, v : UInt64) -> Unit {
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
fn pie_infer_sh_entsize(name : String, sec_ty : UInt) -> UInt64 {
  if name == ".dynamic" || sec_ty == @model.SHT_DYNAMIC {
    16UL
  } else if name == ".hash" || sec_ty == @model.SHT_HASH {
    4UL
  } else if name == ".rela.dyn" || sec_ty == @model.SHT_RELA {
    @model.ELF64_RELA_SIZE.to_uint64()
  } else if name == ".dynsym" || sec_ty == @model.SHT_DYNSYM {
    @model.ELF64_SYM_SIZE.to_uint64()
  } else {
    0UL
  }
}

///|
priv struct PieDynBuild {
  dynstr : Bytes
  needed_offsets : Array[UInt64]
  soname_offset : UInt64
  has_soname : Bool
  sym_name_offsets : Array[UInt]
}

///|
priv struct PieDynRelaRec {
  out_sec : Int
  patch_off : UInt64
  r_info : UInt64
  addend : Int64
}

///|
fn pie_exportable_symbol(sym : @ir.MergedSymbol) -> Bool {
  if sym.name == "" {
    return false
  }
  !(sym.binding is Local)
}

///|
fn pie_append_cstr_with_offset(arr : Array[Byte], s : String) -> UInt {
  let off = arr.length().reinterpret_as_uint()
  for ch in s {
    arr.push(Char::to_int(ch).to_byte())
  }
  arr.push(0)
  off
}

///|
fn pie_build_dynstr(
  soname : String?,
  libs : Array[String],
  exported_symbols : Array[@ir.MergedSymbol],
) -> PieDynBuild {
  let arr : Array[Byte] = [0]
  let offs : Array[UInt64] = []
  let mut soname_offset = 0UL
  let mut has_soname = false
  let sym_name_offsets : Array[UInt] = []
  if soname is Some(name) {
    has_soname = true
    soname_offset = pie_append_cstr_with_offset(arr, name).to_uint64()
  }
  for lib in libs {
    offs.push(pie_append_cstr_with_offset(arr, lib).to_uint64())
  }
  for sym in exported_symbols {
    sym_name_offsets.push(pie_append_cstr_with_offset(arr, sym.name))
  }
  {
    dynstr: Bytes::from_array(arr),
    needed_offsets: offs,
    soname_offset,
    has_soname,
    sym_name_offsets,
  }
}

///|
fn pie_output_basename(path : String) -> String {
  let mut last_sep = -1
  for i, ch in path {
    if ch == '/' || ch == '\\' {
      last_sep = i
    }
  }
  if last_sep >= 0 {
    path[last_sep + 1:].to_string()
  } else {
    path
  }
}

///|
fn pie_build_interp(path : String) -> Bytes {
  let out : Array[Byte] = []
  for ch in path {
    out.push(Char::to_int(ch).to_byte())
  }
  out.push(0)
  Bytes::from_array(out)
}

///|
fn pie_build_dynamic_placeholder(
  needed_count : Int,
  has_soname : Bool,
  has_rela_dyn : Bool,
) -> Bytes {
  // DT_NEEDED[*], optional DT_SONAME, DT_STRTAB, DT_STRSZ, DT_HASH,
  // DT_SYMTAB, DT_SYMENT, optional DT_RELA/DT_RELASZ/DT_RELAENT, DT_NULL
  let entry_count = needed_count +
    (if has_soname { 1 } else { 0 }) +
    6 +
    (if has_rela_dyn { 3 } else { 0 })
  let out : Array[Byte] = []
  for _ in 0..<(entry_count * 16) {
    out.push(0)
  }
  Bytes::from_array(out)
}

///|
fn pie_sysv_hash(name : String) -> UInt {
  let mut h = 0U
  for ch in name {
    h = (h << 4) + Char::to_int(ch).reinterpret_as_uint()
    let g = h & 0xF0000000U
    if g != 0 {
      h = h ^ (g >> 24)
    }
    h = h & (g ^ 0xFFFFFFFFU)
  }
  h
}

///|
fn pie_build_sysv_hash(exported_symbols : Array[@ir.MergedSymbol]) -> Bytes {
  let nchain = 1 + exported_symbols.length()
  let nbucket = if exported_symbols.length() > 0 {
    exported_symbols.length()
  } else {
    1
  }

  let buckets = [0U].repeat(nbucket)
  let chains = [0U].repeat(nchain)

  for i, sym in exported_symbols {
    let sym_index = i + 1
    let b = pie_sysv_hash(sym.name) % nbucket.reinterpret_as_uint()
    let bi = b.reinterpret_as_int()
    if buckets[bi] == 0 {
      buckets[bi] = sym_index.reinterpret_as_uint()
    } else {
      let mut cur = buckets[bi].reinterpret_as_int()
      while chains[cur] != 0 {
        cur = chains[cur].reinterpret_as_int()
      }
      chains[cur] = sym_index.reinterpret_as_uint()
    }
  }

  let out : Array[Byte] = []
  pie_push_u32_le(out, nbucket.reinterpret_as_uint())
  pie_push_u32_le(out, nchain.reinterpret_as_uint())
  for v in buckets {
    pie_push_u32_le(out, v)
  }
  for v in chains {
    pie_push_u32_le(out, v)
  }
  Bytes::from_array(out)
}

///|
fn pie_dynamic_set_entry(
  file : Array[Byte],
  dyn_off : UInt64,
  idx : Int,
  tag : UInt64,
  value : UInt64,
) -> Unit {
  let entry_off = dyn_off.to_int() + idx * 16
  pie_write_u64_le(file, entry_off, tag)
  pie_write_u64_le(file, entry_off + 8, value)
}

///|
fn pie_symbol_binding_to_elf(binding : @ir.SymbolBinding) -> Byte {
  match binding {
    Local => @model.STB_LOCAL
    Global => @model.STB_GLOBAL
    Weak => @model.STB_WEAK
  }
}

///|
fn pie_symbol_type_to_elf(ty : @ir.SymbolType) -> Byte {
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
fn pie_visibility_to_elf(vis : @ir.Visibility) -> Byte {
  match vis {
    Default => @model.STV_DEFAULT
    Internal => @model.STV_INTERNAL
    Hidden => @model.STV_HIDDEN
    Protected => @model.STV_PROTECTED
  }
}

///|
fn pie_build_dynsym(
  exported_symbols : Array[@ir.MergedSymbol],
  sym_name_offsets : Array[UInt],
) -> Bytes {
  let out : Array[Byte] = []

  // NULL symbol
  for _ in 0..<@model.ELF64_SYM_SIZE {
    out.push(0)
  }

  for i in 0..<exported_symbols.length() {
    let sym = exported_symbols[i]
    let st_name = sym_name_offsets[i]
    let st_info = ((pie_symbol_binding_to_elf(sym.binding).to_int() << 4) |
    pie_symbol_type_to_elf(sym.ty).to_int()).to_byte()
    let st_other = pie_visibility_to_elf(sym.vis)
    let st_shndx = if sym.output_sec >= 0 {
      (sym.output_sec + 1).to_uint16()
    } else {
      @model.SHN_UNDEF
    }
    let st_value = if sym.output_sec >= 0 { sym.output_value } else { 0UL }
    let st_size = 0UL

    pie_push_u32_le(out, st_name)
    out.push(st_info)
    out.push(st_other)
    out.push((st_shndx.to_uint() & 0xffU).to_byte())
    out.push(((st_shndx.to_uint() >> 8) & 0xffU).to_byte())
    pie_push_u64_le(out, st_value)
    pie_push_u64_le(out, st_size)
  }

  Bytes::from_array(out)
}

///|
fn pie_build_dyn_rela_records(
  ir : @ir.LinkIr,
  dynsym_index_map : Array[Int],
) -> Array[PieDynRelaRec] {
  let recs : Array[PieDynRelaRec] = []
  for reloc in ir.pending_relocs {
    if !reloc.has_addend {
      continue
    }
    let sym_idx = if reloc.target_sym >= 0 &&
      reloc.target_sym < dynsym_index_map.length() {
      dynsym_index_map[reloc.target_sym].to_uint64()
    } else {
      0UL
    }
    recs.push({
      out_sec: reloc.out_sec,
      patch_off: reloc.patch_off,
      r_info: (sym_idx << 32) | reloc.rel_type.to_uint64(),
      addend: reloc.addend,
    })
  }
  recs
}

///|
fn pie_resolve_entry_addr(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
  section_addrs : Array[UInt64],
) -> UInt64 {
  let entry_candidates : Array[String] = if opts.entry != "" {
    [opts.entry]
  } else if opts.output_kind is @ir.ExecutablePie {
    ["_start", "main"]
  } else {
    []
  }

  for name in entry_candidates {
    let found = ir.merged_symbols.iter().find_first(sym => sym.name == name)
    if found is Some(sym) {
      if sym.output_sec >= 0 && sym.output_sec < section_addrs.length() {
        let sec_name = ir.merged_sections[sym.output_sec].output_name
        let sec_flags = pie_infer_sh_flags(sec_name)
        let is_exec_sec = (sec_flags & @model.SHF_EXECINSTR) != 0UL
        let is_func_sym = sym.ty is @ir.Func
        if is_func_sym || is_exec_sec {
          return section_addrs[sym.output_sec] + sym.output_value
        }
      }
    }
  }

  0UL
}

///|
priv struct PieLoadRange {
  has_alloc : Bool
  file_start : UInt64
  file_end : UInt64
  mem_start : UInt64
  mem_end : UInt64
}

///|
fn pie_empty_load_range() -> PieLoadRange {
  {
    has_alloc: false,
    file_start: 0UL,
    file_end: 0UL,
    mem_start: 0UL,
    mem_end: 0UL,
  }
}

///|
fn pie_extend_load_range(
  range : PieLoadRange,
  sec_ty : UInt,
  sec_flags : UInt64,
  sec_off : UInt64,
  sec_addr : UInt64,
  sec_size : UInt64,
) -> PieLoadRange {
  if (sec_flags & @model.SHF_ALLOC) == 0UL {
    return range
  }

  let first = !range.has_alloc
  let mut mem_start = range.mem_start
  let mut mem_end = range.mem_end
  if first {
    mem_start = sec_addr
    mem_end = sec_addr + sec_size
  } else {
    mem_start = @cmp.minimum(mem_start, sec_addr)
    mem_end = @cmp.maximum(mem_end, sec_addr + sec_size)
  }

  let mut file_start = range.file_start
  let mut file_end = range.file_end
  if sec_ty != @model.SHT_NOBITS {
    if first || file_end == 0UL {
      file_start = sec_off
      file_end = sec_off + sec_size
    } else {
      file_start = @cmp.minimum(file_start, sec_off)
      file_end = @cmp.maximum(file_end, sec_off + sec_size)
    }
  }

  { has_alloc: true, file_start, file_end, mem_start, mem_end }
}

///|
fn pie_build_elf64_dyn(ir : @ir.LinkIr, opts : @ir.LinkOptions) -> Bytes {
  let sections = ir.merged_sections
  let mut has_interp = false
  if opts.output_kind is @ir.ExecutablePie {
    if opts.dynamic_linker is Some(ld) && ld != "" {
      has_interp = true
      sections.push({
        output_name: ".interp",
        output_index: sections.length(),
        align: 1UL,
        bytes: pie_build_interp(ld),
      })
    }
  }

  let mut dyn_needed_offsets : Array[UInt64] = []
  let mut dyn_soname_offset = 0UL
  let mut dyn_has_soname = false
  let exported_symbols : Array[@ir.MergedSymbol] = []
  let dynsym_index_map = [0].repeat(ir.merged_symbols.length())
  let mut has_rela_dyn = false
  let mut dyn_rela_recs : Array[PieDynRelaRec] = []
  let mut has_dynamic = false
  let need_dynamic_for_exe = if opts.output_kind is ExecutablePie {
    opts.dynamic_linker is Some(_)
  } else {
    false
  }
  let soname = if opts.output_kind is SharedLibrary && opts.output != "" {
    opts.output |> pie_output_basename |> Some
  } else {
    None
  }
  if opts.dynamic_libs.length() > 0 || soname is Some(_) || need_dynamic_for_exe {
    for sym in ir.merged_symbols {
      if pie_exportable_symbol(sym) {
        exported_symbols.push(sym)
      }
    }

    // Build a map from merged symbol index to dynsym index (0 means STN_UNDEF).
    let mut dynsym_cursor = 1
    for i, sym in ir.merged_symbols {
      if pie_exportable_symbol(sym) {
        dynsym_index_map[i] = dynsym_cursor
        dynsym_cursor += 1
      }
    }

    dyn_rela_recs = pie_build_dyn_rela_records(ir, dynsym_index_map)
    has_rela_dyn = dyn_rela_recs.length() > 0

    let dyn_build = pie_build_dynstr(
      soname,
      opts.dynamic_libs,
      exported_symbols,
    )
    let dynsym = pie_build_dynsym(exported_symbols, dyn_build.sym_name_offsets)
    let hash = pie_build_sysv_hash(exported_symbols)
    dyn_needed_offsets = dyn_build.needed_offsets
    dyn_soname_offset = dyn_build.soname_offset
    dyn_has_soname = dyn_build.has_soname
    has_dynamic = true
    sections.push({
      output_name: ".hash",
      output_index: sections.length(),
      align: 8UL,
      bytes: hash,
    })
    sections.push({
      output_name: ".dynsym",
      output_index: sections.length(),
      align: 8UL,
      bytes: dynsym,
    })
    sections.push({
      output_name: ".dynstr",
      output_index: sections.length(),
      align: 1UL,
      bytes: dyn_build.dynstr,
    })
    sections.push({
      output_name: ".dynamic",
      output_index: sections.length(),
      align: 8UL,
      bytes: pie_build_dynamic_placeholder(
        opts.dynamic_libs.length(),
        dyn_has_soname,
        has_rela_dyn,
      ),
    })
    if has_rela_dyn {
      let rela_bytes = [b'\x00'].repeat(
          dyn_rela_recs.length() * @model.ELF64_RELA_SIZE,
        )
        |> Bytes::from_array
      sections.push({
        output_name: ".rela.dyn",
        output_index: sections.length(),
        align: 8UL,
        bytes: rela_bytes,
      })
    }
  }

  let section_names : Array[String] = sections.map(sec => sec.output_name)
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

  let shdrs : Array[PieShdr] = [PieShdr::default()]

  let file : Array[Byte] = []
  let e_phoff = @model.ELF64_EHDR_SIZE.to_uint64()
  let max_ph_count = 4
  let ph_size_total = @model.ELF64_PHDR_SIZE * max_ph_count
  let data_start = @model.ELF64_EHDR_SIZE + ph_size_total

  for _ in 0..<data_start {
    file.push(0)
  }

  let mut cursor = data_start
  let mut vcursor = data_start
  let mut rx_range = pie_empty_load_range()
  let mut rw_range = pie_empty_load_range()
  let mut dynstr_addr = 0UL
  let mut dynstr_size = 0UL
  let mut interp_off = 0UL
  let mut interp_addr = 0UL
  let mut interp_size = 0UL
  let mut hash_addr = 0UL
  let mut dynsym_addr = 0UL
  let mut dynamic_off = 0UL
  let mut dynamic_addr = 0UL
  let mut dynamic_size = 0UL
  let mut rela_dyn_off = 0UL
  let mut rela_dyn_addr = 0UL
  let mut rela_dyn_size = 0UL
  let mut dynstr_shidx = 0
  let mut hash_shidx = 0
  let mut dynsym_shidx = 0
  let mut dynamic_shidx = 0
  let mut rela_dyn_shidx = 0
  let merged_sec_count = ir.merged_sections.length()
  let section_addrs = [0UL].repeat(merged_sec_count)
  for i, sec in sections {
    let sec_ty = pie_infer_sh_type(sec.output_name)
    let sec_flags = pie_infer_sh_flags(sec.output_name)
    let sec_entsize = pie_infer_sh_entsize(sec.output_name, sec_ty)
    let sec_align = if sec.align == 0UL { 1UL } else { sec.align }

    vcursor = pie_align_up_int(vcursor, sec_align)
    let sec_addr = vcursor.to_uint64()
    if i < merged_sec_count {
      section_addrs[i] = sec_addr
    }

    let mut sec_off = 0UL
    if sec_ty != @model.SHT_NOBITS {
      cursor = pie_align_up_int(cursor, sec_align)
      sec_off = cursor.to_uint64()
      for _ in file.length()..<cursor {
        file.push(0)
      }
      for b in sec.bytes {
        file.push(b)
      }
      cursor += sec.bytes.length()
    }

    vcursor += sec.bytes.length()

    let sh_index = i + 1
    match sec.output_name {
      ".interp" => {
        interp_off = sec_off
        interp_addr = sec_addr
        interp_size = sec.bytes.length().to_uint64()
      }
      ".dynsym" => {
        dynsym_addr = sec_addr
        dynsym_shidx = sh_index
      }
      ".hash" => {
        hash_addr = sec_addr
        hash_shidx = sh_index
      }
      ".dynstr" => {
        dynstr_addr = sec_addr
        dynstr_size = sec.bytes.length().to_uint64()
        dynstr_shidx = sh_index
      }
      ".dynamic" => {
        dynamic_off = sec_off
        dynamic_addr = sec_addr
        dynamic_size = sec.bytes.length().to_uint64()
        dynamic_shidx = sh_index
      }
      ".rela.dyn" => {
        rela_dyn_off = sec_off
        rela_dyn_addr = sec_addr
        rela_dyn_size = sec.bytes.length().to_uint64()
        rela_dyn_shidx = sh_index
      }
      _ => ()
    }

    if (sec_flags & @model.SHF_ALLOC) != 0UL {
      if (sec_flags & @model.SHF_WRITE) != 0UL {
        rw_range = pie_extend_load_range(
          rw_range,
          sec_ty,
          sec_flags,
          sec_off,
          sec_addr,
          sec.bytes.length().to_uint64(),
        )
      } else {
        rx_range = pie_extend_load_range(
          rx_range,
          sec_ty,
          sec_flags,
          sec_off,
          sec_addr,
          sec.bytes.length().to_uint64(),
        )
      }
    }

    shdrs.push({
      sh_name: sh_name_offsets[i],
      sh_type: sec_ty,
      sh_flags: sec_flags,
      sh_addr: sec_addr,
      sh_offset: sec_off,
      sh_size: sec.bytes.length().to_uint64(),
      sh_link: match sec.output_name {
        ".dynamic" | ".dynsym" => dynstr_shidx.reinterpret_as_uint()
        ".hash" => dynsym_shidx.reinterpret_as_uint()
        ".rela.dyn" => dynsym_shidx.reinterpret_as_uint()
        _ => 0
      },
      sh_info: if sec.output_name == ".dynsym" {
        1
      } else {
        0
      },
      sh_addralign: sec_align,
      sh_entsize: sec_entsize,
    })
  }

  if has_dynamic && dynamic_shidx > 0 {
    let dynamic_hdr = shdrs[dynamic_shidx]
    shdrs[dynamic_shidx] = {
      ..dynamic_hdr,
      sh_link: dynstr_shidx.reinterpret_as_uint(),
    }
  }
  if has_dynamic && dynsym_shidx > 0 {
    let dynsym_hdr = shdrs[dynsym_shidx]
    shdrs[dynsym_shidx] = {
      ..dynsym_hdr,
      sh_link: dynstr_shidx.reinterpret_as_uint(),
      sh_info: 1,
    }
  }
  if has_dynamic && hash_shidx > 0 {
    let hash_hdr = shdrs[hash_shidx]
    shdrs[hash_shidx] = {
      ..hash_hdr,
      sh_link: dynsym_shidx.reinterpret_as_uint(),
    }
  }
  if has_dynamic && rela_dyn_shidx > 0 {
    let rela_dyn_hdr = shdrs[rela_dyn_shidx]
    shdrs[rela_dyn_shidx] = {
      ..rela_dyn_hdr,
      sh_type: @model.SHT_RELA,
      sh_link: dynsym_shidx.reinterpret_as_uint(),
      sh_entsize: @model.ELF64_RELA_SIZE.to_uint64(),
      sh_addralign: 8UL,
    }
  }

  if has_dynamic && has_rela_dyn {
    for i, rec in dyn_rela_recs {
      if rec.out_sec < 0 || rec.out_sec >= section_addrs.length() {
        continue
      }
      let r_off = section_addrs[rec.out_sec] + rec.patch_off
      let entry_off = rela_dyn_off.to_int() + i * @model.ELF64_RELA_SIZE
      pie_write_u64_le(file, entry_off, r_off)
      pie_write_u64_le(file, entry_off + 8, rec.r_info)
      pie_write_u64_le(file, entry_off + 16, rec.addend.reinterpret_as_uint64())
    }
  }

  let shstr_off = cursor.to_uint64()
  for b in shstr_bytes {
    file.push(b)
  }
  cursor += shstr_bytes.length()

  shdrs.push({
    sh_name: sh_name_offsets[section_names.length() - 1],
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

  cursor = pie_align_up_int(cursor, 8UL)
  let e_shoff = cursor.to_uint64()
  for _ in file.length()..<cursor {
    file.push(0)
  }

  for sh in shdrs {
    pie_push_u32_le(file, sh.sh_name)
    pie_push_u32_le(file, sh.sh_type)
    pie_push_u64_le(file, sh.sh_flags)
    pie_push_u64_le(file, sh.sh_addr)
    pie_push_u64_le(file, sh.sh_offset)
    pie_push_u64_le(file, sh.sh_size)
    pie_push_u32_le(file, sh.sh_link)
    pie_push_u32_le(file, sh.sh_info)
    pie_push_u64_le(file, sh.sh_addralign)
    pie_push_u64_le(file, sh.sh_entsize)
  }

  file[@model.EI_MAG0] = @model.ELFMAG0
  file[@model.EI_MAG1] = @model.ELFMAG1
  file[@model.EI_MAG2] = @model.ELFMAG2
  file[@model.EI_MAG3] = @model.ELFMAG3
  file[@model.EI_CLASS] = @model.ELFCLASS64
  file[@model.EI_DATA] = @model.ELFDATA2LSB
  file[@model.EI_VERSION] = 1
  file[@model.EI_OSABI] = 0
  file[@model.EI_ABIVERSION] = 0

  pie_write_u16_le(file, 16, @model.ET_DYN)
  pie_write_u16_le(file, 18, pie_machine_from_arch(ir.arch))
  pie_write_u32_le(file, 20, 1)
  let entry_addr = pie_resolve_entry_addr(ir, opts, section_addrs)
  pie_write_u64_le(file, 24, entry_addr)
  pie_write_u64_le(file, 32, e_phoff)
  pie_write_u64_le(file, 40, e_shoff)
  pie_write_u32_le(file, 48, 0)
  pie_write_u16_le(file, 52, @model.ELF64_EHDR_SIZE.to_uint16())
  pie_write_u16_le(file, 54, @model.ELF64_PHDR_SIZE.to_uint16())

  let ph_count = (if rx_range.has_alloc { 1 } else { 0 }) +
    (if rw_range.has_alloc { 1 } else { 0 }) +
    (if has_interp { 1 } else { 0 }) +
    (if has_dynamic { 1 } else { 0 })
  pie_write_u16_le(file, 56, ph_count.to_uint16())
  pie_write_u16_le(file, 58, @model.ELF64_SHDR_SIZE.to_uint16())
  pie_write_u16_le(file, 60, shdrs.length().to_uint16())
  pie_write_u16_le(file, 62, (shdrs.length() - 1).to_uint16())

  let mut ph_idx = 0
  if rx_range.has_alloc {
    let ph_off = e_phoff.to_int() + ph_idx * @model.ELF64_PHDR_SIZE
    let file_start = rx_range.file_start
    let file_end = @cmp.maximum(rx_range.file_end, file_start)
    pie_write_u32_le(file, ph_off, @model.PT_LOAD)
    pie_write_u32_le(file, ph_off + 4, @model.PF_R | @model.PF_X)
    pie_write_u64_le(file, ph_off + 8, file_start)
    pie_write_u64_le(file, ph_off + 16, rx_range.mem_start)
    pie_write_u64_le(file, ph_off + 24, rx_range.mem_start)
    pie_write_u64_le(file, ph_off + 32, file_end - file_start)
    pie_write_u64_le(file, ph_off + 40, rx_range.mem_end - rx_range.mem_start)
    pie_write_u64_le(file, ph_off + 48, 0x1000UL)
    ph_idx += 1
  }

  if rw_range.has_alloc {
    let ph_off = e_phoff.to_int() + ph_idx * @model.ELF64_PHDR_SIZE
    let file_start = rw_range.file_start
    let file_end = @cmp.maximum(rw_range.file_end, file_start)
    pie_write_u32_le(file, ph_off, @model.PT_LOAD)
    pie_write_u32_le(file, ph_off + 4, @model.PF_R | @model.PF_W)
    pie_write_u64_le(file, ph_off + 8, file_start)
    pie_write_u64_le(file, ph_off + 16, rw_range.mem_start)
    pie_write_u64_le(file, ph_off + 24, rw_range.mem_start)
    pie_write_u64_le(file, ph_off + 32, file_end - file_start)
    pie_write_u64_le(file, ph_off + 40, rw_range.mem_end - rw_range.mem_start)
    pie_write_u64_le(file, ph_off + 48, 0x1000UL)
    ph_idx += 1
  }

  if has_interp {
    let ph_off = e_phoff.to_int() + ph_idx * @model.ELF64_PHDR_SIZE
    pie_write_u32_le(file, ph_off, @model.PT_INTERP)
    pie_write_u32_le(file, ph_off + 4, @model.PF_R)
    pie_write_u64_le(file, ph_off + 8, interp_off)
    pie_write_u64_le(file, ph_off + 16, interp_addr)
    pie_write_u64_le(file, ph_off + 24, interp_addr)
    pie_write_u64_le(file, ph_off + 32, interp_size)
    pie_write_u64_le(file, ph_off + 40, interp_size)
    pie_write_u64_le(file, ph_off + 48, 1UL)
    ph_idx += 1
  }

  if has_dynamic {
    let ph_off = e_phoff.to_int() + ph_idx * @model.ELF64_PHDR_SIZE
    pie_write_u32_le(file, ph_off, @model.PT_DYNAMIC)
    pie_write_u32_le(file, ph_off + 4, @model.PF_R | @model.PF_W)
    pie_write_u64_le(file, ph_off + 8, dynamic_off)
    pie_write_u64_le(file, ph_off + 16, dynamic_addr)
    pie_write_u64_le(file, ph_off + 24, dynamic_addr)
    pie_write_u64_le(file, ph_off + 32, dynamic_size)
    pie_write_u64_le(file, ph_off + 40, dynamic_size)
    pie_write_u64_le(file, ph_off + 48, 8UL)
  }

  if has_dynamic {
    // Dynamic tags for the minimal loader contract.
    let dt_null = 0UL
    let dt_needed = 1UL
    let dt_soname = 14UL
    let dt_hash = 4UL
    let dt_strtab = 5UL
    let dt_symtab = 6UL
    let dt_rela = 7UL
    let dt_relasz = 8UL
    let dt_relaent = 9UL
    let dt_strsz = 10UL
    let dt_syment = 11UL

    let mut dyn_idx = 0
    for off in dyn_needed_offsets {
      pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_needed, off)
      dyn_idx += 1
    }
    if dyn_has_soname {
      pie_dynamic_set_entry(
        file, dynamic_off, dyn_idx, dt_soname, dyn_soname_offset,
      )
      dyn_idx += 1
    }
    pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_strtab, dynstr_addr)
    dyn_idx += 1
    pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_strsz, dynstr_size)
    dyn_idx += 1
    pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_hash, hash_addr)
    dyn_idx += 1
    pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_symtab, dynsym_addr)
    dyn_idx += 1
    pie_dynamic_set_entry(
      file,
      dynamic_off,
      dyn_idx,
      dt_syment,
      @model.ELF64_SYM_SIZE.to_uint64(),
    )
    dyn_idx += 1
    if has_rela_dyn {
      pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_rela, rela_dyn_addr)
      dyn_idx += 1
      pie_dynamic_set_entry(
        file, dynamic_off, dyn_idx, dt_relasz, rela_dyn_size,
      )
      dyn_idx += 1
      pie_dynamic_set_entry(
        file,
        dynamic_off,
        dyn_idx,
        dt_relaent,
        @model.ELF64_RELA_SIZE.to_uint64(),
      )
      dyn_idx += 1
    }
    pie_dynamic_set_entry(file, dynamic_off, dyn_idx, dt_null, 0UL)
  }

  Bytes::from_array(file)
}

///|
/// Write PIE or shared library output
pub fn write_pie_or_shared(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkArtifact raise @ir.WriteError {
  if opts.output_kind is Relocatable {
    raise InvalidOutputKind(
      "write_pie_or_shared cannot emit relocatable output",
    )
  }
  if ir.input_objects.length() == 0 {
    raise LayoutFailure("no input object to emit")
  }

  let payload = match ir.merged_sections {
    [] => {
      if ir.input_objects.length() > 1 {
        raise LayoutFailure(
          "no merged output sections for multi-input \{opts.output_kind.to_string()} build",
        )
      }
      // Keep backward compatibility for minimal single-input flow.
      ir.input_objects[0].raw
    }
    [_, ..] => pie_build_elf64_dyn(ir, opts)
  }

  {
    bytes: payload,
    map_text: Some(
      "elf64 ET_DYN payload for \{opts.output_kind.to_string()} from \{ir.merged_sections.length()} merged sections",
    ),
  }
}
