///| Write relocatable ELF output

///|
fn align_up_int(value : Int, align : UInt64) -> Int {
  let a = align.to_int()
  if a <= 1 {
    return value
  }
  ((value + a - 1) / a) * a
}

///|
fn serialize_merged_sections(sections : Array[@ir.MergedSection]) -> Bytes {
  let out : Array[Byte] = []
  for sec in sections {
    let aligned = align_up_int(out.length(), sec.align)
    for _ in out.length()..<aligned {
      out.push(0)
    }
    for b in sec.bytes {
      out.push(b)
    }
  }
  Bytes::from_array(out)
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
    // Keep backward compatibility for minimal single-input flow.
    return {
      bytes: ir.input_objects[0].raw,
      map_text: Some("mvp: passthrough relocatable output"),
    }
  }

  let payload = serialize_merged_sections(ir.merged_sections)

  {
    bytes: payload,
    map_text: Some(
      "relocatable payload from \{ir.merged_sections.length()} sections, align=\{opts.section_align}",
    ),
  }
}
