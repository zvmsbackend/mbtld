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
    @ir.X86_64 => @model.EM_X86_64
    @ir.AARCH64 => @model.EM_AARCH64
    @ir.RISCV64 => @model.EM_RISCV
    @ir.LOONGARCH64 => @model.EM_LOONGARCH
  }
}

///|
fn pie_starts_with(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  s[:prefix.length()].to_string() == prefix
}

///|
fn pie_infer_sh_type(name : String) -> UInt {
  if name == ".bss" || name == ".tbss" {
    @model.SHT_NOBITS
  } else if name == ".init_array" {
    @model.SHT_INIT_ARRAY
  } else if name == ".fini_array" {
    @model.SHT_FINI_ARRAY
  } else if name == ".preinit_array" {
    @model.SHT_PREINIT_ARRAY
  } else {
    @model.SHT_PROGBITS
  }
}

///|
fn pie_infer_sh_flags(name : String) -> UInt64 {
  let mut flags = 0UL
  if name == ".text" || name == ".init" || name == ".fini" {
    flags = @model.SHF_ALLOC | @model.SHF_EXECINSTR
  } else if name == ".rodata" {
    flags = @model.SHF_ALLOC
  } else {
    flags = @model.SHF_ALLOC | @model.SHF_WRITE
  }

  if pie_starts_with(name, ".t") {
    flags = flags | @model.SHF_TLS
  }

  flags
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
}

///|
fn pie_shdr_zero() -> PieShdr {
  {
    sh_name: 0,
    sh_type: 0,
    sh_flags: 0,
    sh_addr: 0,
    sh_offset: 0,
    sh_size: 0,
    sh_link: 0,
    sh_info: 0,
    sh_addralign: 0,
    sh_entsize: 0,
  }
}

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
fn pie_max_u64(a : UInt64, b : UInt64) -> UInt64 {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn pie_min_u64(a : UInt64, b : UInt64) -> UInt64 {
  if a < b {
    a
  } else {
    b
  }
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
    mem_start = pie_min_u64(mem_start, sec_addr)
    mem_end = pie_max_u64(mem_end, sec_addr + sec_size)
  }

  let mut file_start = range.file_start
  let mut file_end = range.file_end
  if sec_ty != @model.SHT_NOBITS {
    if first || file_end == 0UL {
      file_start = sec_off
      file_end = sec_off + sec_size
    } else {
      file_start = pie_min_u64(file_start, sec_off)
      file_end = pie_max_u64(file_end, sec_off + sec_size)
    }
  }

  { has_alloc: true, file_start, file_end, mem_start, mem_end }
}

///|
fn pie_build_elf64_dyn(ir : @ir.LinkIr) -> Bytes {
  let section_names : Array[String] = []
  for sec in ir.merged_sections {
    section_names.push(sec.output_name)
  }
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

  let shdrs : Array[PieShdr] = []
  shdrs.push(pie_shdr_zero())

  let file : Array[Byte] = []
  let e_phoff = @model.ELF64_EHDR_SIZE.to_uint64()
  let max_ph_count = 2
  let ph_size_total = @model.ELF64_PHDR_SIZE * max_ph_count
  let data_start = @model.ELF64_EHDR_SIZE + ph_size_total

  for _ in 0..<data_start {
    file.push(0)
  }

  let mut cursor = data_start
  let mut vcursor = data_start
  let mut rx_range = pie_empty_load_range()
  let mut rw_range = pie_empty_load_range()
  for i = 0; i < ir.merged_sections.length(); i = i + 1 {
    let sec = ir.merged_sections[i]
    let sec_ty = pie_infer_sh_type(sec.output_name)
    let sec_flags = pie_infer_sh_flags(sec.output_name)
    let sec_align = if sec.align == 0UL { 1UL } else { sec.align }

    vcursor = pie_align_up_int(vcursor, sec_align)
    let sec_addr = vcursor.to_uint64()

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
      sh_link: 0,
      sh_info: 0,
      sh_addralign: sec_align,
      sh_entsize: 0,
    })
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
  pie_write_u64_le(file, 24, 0UL)
  pie_write_u64_le(file, 32, e_phoff)
  pie_write_u64_le(file, 40, e_shoff)
  pie_write_u32_le(file, 48, 0)
  pie_write_u16_le(file, 52, @model.ELF64_EHDR_SIZE.to_uint16())
  pie_write_u16_le(file, 54, @model.ELF64_PHDR_SIZE.to_uint16())

  let ph_count = (if rx_range.has_alloc { 1 } else { 0 }) +
    (if rw_range.has_alloc { 1 } else { 0 })
  pie_write_u16_le(file, 56, ph_count.to_uint16())
  pie_write_u16_le(file, 58, @model.ELF64_SHDR_SIZE.to_uint16())
  pie_write_u16_le(file, 60, shdrs.length().to_uint16())
  pie_write_u16_le(file, 62, (shdrs.length() - 1).to_uint16())

  let mut ph_idx = 0
  if rx_range.has_alloc {
    let ph_off = e_phoff.to_int() + ph_idx * @model.ELF64_PHDR_SIZE
    let file_start = rx_range.file_start
    let file_end = pie_max_u64(rx_range.file_end, file_start)
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
    let file_end = pie_max_u64(rw_range.file_end, file_start)
    pie_write_u32_le(file, ph_off, @model.PT_LOAD)
    pie_write_u32_le(file, ph_off + 4, @model.PF_R | @model.PF_W)
    pie_write_u64_le(file, ph_off + 8, file_start)
    pie_write_u64_le(file, ph_off + 16, rw_range.mem_start)
    pie_write_u64_le(file, ph_off + 24, rw_range.mem_start)
    pie_write_u64_le(file, ph_off + 32, file_end - file_start)
    pie_write_u64_le(file, ph_off + 40, rw_range.mem_end - rw_range.mem_start)
    pie_write_u64_le(file, ph_off + 48, 0x1000UL)
  }

  Bytes::from_array(file)
}

///|
/// Write PIE or shared library output
pub fn write_pie_or_shared(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkArtifact raise @ir.WriteError {
  if opts.output_kind == @ir.Relocatable {
    raise InvalidOutputKind(
      "write_pie_or_shared cannot emit relocatable output",
    )
  }
  if ir.input_objects.length() == 0 {
    raise LayoutFailure("no input object to emit")
  }

  let payload = if ir.merged_sections.length() == 0 {
    if ir.input_objects.length() > 1 {
      raise LayoutFailure(
        "no merged output sections for multi-input \{opts.output_kind.to_string()} build",
      )
    }
    // Keep backward compatibility for minimal single-input flow.
    ir.input_objects[0].raw
  } else {
    pie_build_elf64_dyn(ir)
  }

  {
    bytes: payload,
    map_text: Some(
      "elf64 ET_DYN payload for \{opts.output_kind.to_string()} from \{ir.merged_sections.length()} merged sections",
    ),
  }
}
