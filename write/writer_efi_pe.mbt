///| Write EFI PE/COFF output

///|
fn efi_align_up_int(value : Int, align : UInt64) -> Int {
  let a = align.to_int()
  if a <= 1 {
    return value
  }
  (value + a - 1) / a * a
}

///|
fn efi_write_u16_le(out : Array[Byte], offset : Int, v : UInt16) -> Unit {
  let vv = v.to_uint()
  out[offset] = (vv & 0xffU).to_byte()
  out[offset + 1] = ((vv >> 8) & 0xffU).to_byte()
}

///|
fn efi_write_u32_le(out : Array[Byte], offset : Int, v : UInt) -> Unit {
  out[offset] = (v & 0xffU).to_byte()
  out[offset + 1] = ((v >> 8) & 0xffU).to_byte()
  out[offset + 2] = ((v >> 16) & 0xffU).to_byte()
  out[offset + 3] = ((v >> 24) & 0xffU).to_byte()
}

///|
fn efi_write_u64_le(out : Array[Byte], offset : Int, v : UInt64) -> Unit {
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
fn efi_subsystem(kind : @ir.OutputKind) -> UInt16 {
  match kind {
    @ir.EfiApplication => 10 // IMAGE_SUBSYSTEM_EFI_APPLICATION
    @ir.EfiBootDriver => 11 // IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER
    @ir.EfiRuntimeDriver => 12 // IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER
    _ => 0
  }
}

///|
fn efi_machine(arch : @ir.Arch) -> UInt16 raise @ir.WriteError {
  match arch {
    @ir.X86_64 => 0x8664 // IMAGE_FILE_MACHINE_AMD64
    @ir.AARCH64 => 0xAA64 // IMAGE_FILE_MACHINE_ARM64
    _ =>
      raise InvalidOutputKind(
        "EFI PE/COFF writer currently supports x86_64 and aarch64",
      )
  }
}

///|
fn efi_is_exec_section_name(name : String) -> Bool {
  name == ".text" ||
  name == ".init" ||
  name == ".fini" ||
  name.has_prefix(".text.")
}

///|
fn efi_entry_candidates(opts : @ir.LinkOptions) -> Array[String] {
  match opts.entry {
    "" => ["efi_main", "_start", "main"]
    _ => [opts.entry]
  }
}

///|
fn efi_find_entry_symbol(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.MergedSymbol? {
  let candidates = efi_entry_candidates(opts)
  for name in candidates {
    let idx = ir.merged_symbols.search_by(sym => sym.name == name)
    if idx is Some(i) {
      let sym = ir.merged_symbols[i]
      if sym.output_sec < 0 || sym.output_sec >= ir.merged_sections.length() {
        continue
      }
      let sec_name = ir.merged_sections[sym.output_sec].output_name
      if sym.ty is @ir.Func || efi_is_exec_section_name(sec_name) {
        return Some(sym)
      }
    }
  }
  None
}

///|
fn efi_section_name(name : String) -> String {
  if name == ".rodata" {
    ".rdata"
  } else if name.has_prefix(".rodata") {
    ".rdata"
  } else {
    name
  }
}

///|
fn efi_section_characteristics(name : String) -> UInt {
  if efi_is_exec_section_name(name) {
    0x60000020 // CNT_CODE | MEM_EXECUTE | MEM_READ
  } else if name == ".rdata" || name == ".rodata" || name.has_prefix(".rodata") {
    0x40000040 // CNT_INITIALIZED_DATA | MEM_READ
  } else if name == ".bss" || name == ".tbss" {
    0xC0000080 // CNT_UNINITIALIZED_DATA | MEM_READ | MEM_WRITE
  } else {
    0xC0000040 // CNT_INITIALIZED_DATA | MEM_READ | MEM_WRITE
  }
}

///|
fn efi_is_nobits(name : String) -> Bool {
  name == ".bss" || name == ".tbss"
}

///|
priv struct EfiPlacedSection {
  name : String
  rva : UInt
  virtual_size : UInt
  raw_off : UInt
  raw_size : UInt
  chars : UInt
  bytes : Bytes
}

///|
fn efi_build_image(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> Bytes raise @ir.WriteError {
  let file_align = 0x200UL
  let section_align = if opts.section_align == 0 {
    0x1000UL
  } else {
    opts.section_align.to_uint64()
  }

  let dos_size = 0x80
  let pe_sig_off = dos_size
  let coff_size = 20
  let opt_size = 0xF0
  let sec_hdr_size = 40
  let sec_count = ir.merged_sections.length()
  let headers_end = pe_sig_off +
    4 +
    coff_size +
    opt_size +
    sec_count * sec_hdr_size
  let headers_size = efi_align_up_int(headers_end, file_align).reinterpret_as_uint()

  let section_rvas = [0U].repeat(ir.merged_sections.length())
  let mut cur_rva = efi_align_up_int(
    headers_size.reinterpret_as_int(),
    section_align,
  ).reinterpret_as_uint()
  let mut cur_raw = headers_size.reinterpret_as_int()

  let placed : Array[EfiPlacedSection] = []
  for i, sec in ir.merged_sections {
    let name = efi_section_name(sec.output_name)
    let virtual_size = sec.bytes.length().reinterpret_as_uint()
    let is_nobits = efi_is_nobits(sec.output_name)
    let raw_size = if is_nobits {
      0U
    } else {
      efi_align_up_int(sec.bytes.length(), file_align).reinterpret_as_uint()
    }
    let raw_off = if raw_size == 0 {
      0U
    } else {
      efi_align_up_int(cur_raw, file_align).reinterpret_as_uint()
    }

    cur_rva = efi_align_up_int(cur_rva.reinterpret_as_int(), section_align).reinterpret_as_uint()
    section_rvas[i] = cur_rva
    placed.push({
      name,
      rva: cur_rva,
      virtual_size,
      raw_off,
      raw_size,
      chars: efi_section_characteristics(sec.output_name),
      bytes: sec.bytes,
    })

    cur_rva += efi_align_up_int(
      virtual_size.reinterpret_as_int(),
      section_align,
    ).reinterpret_as_uint()
    if raw_size > 0 {
      cur_raw = raw_off.reinterpret_as_int() + raw_size.reinterpret_as_int()
    }
  }

  let image_size = efi_align_up_int(cur_rva.reinterpret_as_int(), section_align).reinterpret_as_uint()
  let file_size = efi_align_up_int(cur_raw, file_align)
  let out = [b'\x00'].repeat(file_size)

  // DOS header and stub
  out[0] = b'M'
  out[1] = b'Z'
  efi_write_u32_le(out, 0x3C, pe_sig_off.reinterpret_as_uint())

  // PE signature
  out[pe_sig_off] = b'P'
  out[pe_sig_off + 1] = b'E'
  out[pe_sig_off + 2] = 0
  out[pe_sig_off + 3] = 0

  // COFF header
  let coff_off = pe_sig_off + 4
  efi_write_u16_le(out, coff_off, efi_machine(ir.arch))
  efi_write_u16_le(out, coff_off + 2, sec_count.to_uint16())
  efi_write_u32_le(out, coff_off + 4, 0)
  efi_write_u32_le(out, coff_off + 8, 0)
  efi_write_u32_le(out, coff_off + 12, 0)
  efi_write_u16_le(out, coff_off + 16, opt_size.to_uint16())
  efi_write_u16_le(out, coff_off + 18, 0x0022) // EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE

  // Optional header (PE32+)
  let opt_off = coff_off + coff_size
  efi_write_u16_le(out, opt_off, 0x20B)
  out[opt_off + 2] = 0
  out[opt_off + 3] = 0

  let mut size_code = 0U
  let mut size_init_data = 0U
  let mut size_uninit_data = 0U
  let mut base_of_code = 0U
  let mut entry_rva = 0U
  for sec in placed {
    if (sec.chars & 0x00000020U) != 0 {
      size_code += sec.raw_size
      if base_of_code == 0 {
        base_of_code = sec.rva
      }
    } else if (sec.chars & 0x00000080U) != 0 {
      size_uninit_data += sec.virtual_size
    } else {
      size_init_data += sec.raw_size
    }
  }

  match efi_find_entry_symbol(ir, opts) {
    Some(sym) => {
      let sec_rva = section_rvas[sym.output_sec]
      entry_rva = sec_rva + sym.output_value.to_uint()
    }
    None =>
      raise LayoutFailure(
        "EFI output requires an executable entry symbol (efi_main/_start/main or --entry-point)",
      )
  }

  efi_write_u32_le(out, opt_off + 4, size_code)
  efi_write_u32_le(out, opt_off + 8, size_init_data)
  efi_write_u32_le(out, opt_off + 12, size_uninit_data)
  efi_write_u32_le(out, opt_off + 16, entry_rva)
  efi_write_u32_le(out, opt_off + 20, base_of_code)
  efi_write_u64_le(out, opt_off + 24, opts.start_address)
  efi_write_u32_le(out, opt_off + 32, section_align.to_uint())
  efi_write_u32_le(out, opt_off + 36, file_align.to_uint())
  efi_write_u16_le(out, opt_off + 40, 0)
  efi_write_u16_le(out, opt_off + 42, 0)
  efi_write_u16_le(out, opt_off + 44, 0)
  efi_write_u16_le(out, opt_off + 46, 0)
  efi_write_u16_le(out, opt_off + 48, 0)
  efi_write_u16_le(out, opt_off + 50, 0)
  efi_write_u32_le(out, opt_off + 52, 0)
  efi_write_u32_le(out, opt_off + 56, image_size)
  efi_write_u32_le(out, opt_off + 60, headers_size)
  efi_write_u32_le(out, opt_off + 64, 0)
  efi_write_u16_le(out, opt_off + 68, efi_subsystem(opts.output_kind))
  efi_write_u16_le(out, opt_off + 70, 0)
  efi_write_u64_le(out, opt_off + 72, 0x100000UL)
  efi_write_u64_le(out, opt_off + 80, 0x1000UL)
  efi_write_u64_le(out, opt_off + 88, 0x100000UL)
  efi_write_u64_le(out, opt_off + 96, 0x1000UL)
  efi_write_u32_le(out, opt_off + 104, 0)
  efi_write_u32_le(out, opt_off + 108, 16)

  // Section headers
  let sec_hdr_off = opt_off + opt_size
  for i, sec in placed {
    let off = sec_hdr_off + i * sec_hdr_size
    let bytes = sec.name.iter().map(ch => Char::to_int(ch).to_byte()).collect()
    for j in 0..<@cmp.minimum(bytes.length(), 8) {
      out[off + j] = bytes[j]
    }
    efi_write_u32_le(out, off + 8, sec.virtual_size)
    efi_write_u32_le(out, off + 12, sec.rva)
    efi_write_u32_le(out, off + 16, sec.raw_size)
    efi_write_u32_le(out, off + 20, sec.raw_off)
    efi_write_u32_le(out, off + 24, 0)
    efi_write_u32_le(out, off + 28, 0)
    efi_write_u16_le(out, off + 32, 0)
    efi_write_u16_le(out, off + 34, 0)
    efi_write_u32_le(out, off + 36, sec.chars)
  }

  // Section payloads
  for sec in placed {
    if sec.raw_size == 0 {
      continue
    }
    let base = sec.raw_off.reinterpret_as_int()
    for i, b in sec.bytes {
      out[base + i] = b
    }
  }

  Bytes::from_array(out)
}

///|
/// Write EFI output as PE/COFF image
pub fn write_efi_image(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkArtifact raise @ir.WriteError {
  if !(opts.output_kind
    is (@ir.EfiApplication | @ir.EfiBootDriver | @ir.EfiRuntimeDriver)) {
    raise InvalidOutputKind("write_efi_image only supports EFI output kinds")
  }

  if ir.input_objects.length() == 0 {
    raise LayoutFailure("no input object to emit")
  }

  if ir.merged_sections.length() == 0 {
    raise LayoutFailure("no merged output sections for EFI build")
  }

  let payload = efi_build_image(ir, opts)
  if opts.linker_heap_size is Some(limit) &&
    payload.length().to_uint64() > limit {
    raise LayoutFailure(
      "output exceeds linker heap size: payload=\{payload.length()} limit=\{limit}",
    )
  }

  {
    bytes: payload,
    map_text: Some(
      "efi pe/coff payload for \{opts.output_kind} from \{ir.merged_sections.length()} merged sections",
    ),
  }
}
