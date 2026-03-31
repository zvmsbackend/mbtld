///| Write relocatable ELF output

///|
/// Write relocatable output
pub fn write_relocatable(
  ir : @ir.LinkIr,
  _opts : @ir.LinkOptions,
) -> @ir.LinkArtifact raise @ir.WriteError {
  if ir.input_objects.length() == 0 {
    raise LayoutFailure("no input object to emit")
  }
  if ir.input_objects.length() > 1 {
    raise LayoutFailure(
      "MVP supports exactly one input object for relocatable output",
    )
  }
  {
    bytes: ir.input_objects[0].raw,
    map_text: Some("mvp: passthrough relocatable output"),
  }
}
