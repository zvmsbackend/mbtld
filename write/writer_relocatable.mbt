///| Write relocatable ELF output

///|
/// Write relocatable output
pub fn write_relocatable(
  ir : @ir.LinkIr,
  opts : @ir.LinkOptions,
) -> @ir.LinkArtifact raise @ir.WriteError {
  raise LayoutFailure("not implemented")
}
