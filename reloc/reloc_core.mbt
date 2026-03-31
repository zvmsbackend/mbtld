///| Relocation core engine

///|
/// Apply relocations to IR
pub fn apply_relocations(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkIr raise @ir.RelocError {
  if opts.output_kind == @ir.Relocatable {
    for pending in ir.pending_relocs {
      if !is_reloc_supported(ir.arch, pending.rel_type) {
        raise UnsupportedRelocType(pending.rel_type)
      }
    }
    return ir
  }

  let sections = ir.merged_sections

  for pending in ir.pending_relocs {
    if !is_reloc_supported(ir.arch, pending.rel_type) {
      raise UnsupportedRelocType(pending.rel_type)
    }

    if pending.out_sec < 0 || pending.out_sec >= sections.length() {
      raise BadRelocTarget("invalid section index \{pending.out_sec}")
    }

    if pending.target_sym < 0 ||
      pending.target_sym >= ir.merged_symbols.length() {
      if opts.output_kind == @ir.Relocatable {
        continue
      }
      raise BadRelocTarget("invalid symbol index \{pending.target_sym}")
    }

    let sym = ir.merged_symbols[pending.target_sym]
    let sym_value = if sym.output_sec < 0 {
      if opts.output_kind == @ir.Relocatable {
        0UL
      } else {
        raise BadRelocTarget("unresolved symbol \{sym.name}")
      }
    } else {
      sym.output_value
    }

    let sec = sections[pending.out_sec]
    let patched = match ir.arch {
      X86_64 =>
        apply_x86_64_reloc(
          sec.bytes,
          pending.patch_off,
          pending.rel_type,
          sym_value,
          pending.addend,
          pending.patch_off,
        )
      _ => raise UnsupportedRelocType(pending.rel_type)
    }

    sections[pending.out_sec] = { ..sec, bytes: patched }
  }

  { ..ir, merged_sections: sections }
}

///|
/// Check if relocation type is supported
pub fn is_reloc_supported(arch : @ir.Arch, rel_type : UInt) -> Bool {
  match arch {
    X86_64 => is_x86_64_reloc_supported(rel_type)
    AARCH64 => is_aarch64_reloc_supported(rel_type)
    RISCV64 => is_riscv64_reloc_supported(rel_type)
    LOONGARCH64 => is_loongarch64_reloc_supported(rel_type)
  }
}

///|
fn is_x86_64_reloc_supported(rel_type : UInt) -> Bool {
  rel_type <= 15 || rel_type == 24 || rel_type == 26 || rel_type == 38
}

///|
fn is_aarch64_reloc_supported(rel_type : UInt) -> Bool {
  rel_type >= 257 && rel_type <= 262
}

///|
fn is_riscv64_reloc_supported(rel_type : UInt) -> Bool {
  rel_type <= 2
}

///|
fn is_loongarch64_reloc_supported(rel_type : UInt) -> Bool {
  rel_type <= 3
}
