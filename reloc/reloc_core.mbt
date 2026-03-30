///| Relocation core engine

///|
/// Apply relocations to IR
pub fn apply_relocations(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkIr raise @ir.RelocError {
  ir
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
