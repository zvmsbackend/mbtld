///| Write PIE/Shared library output

///|
fn pie_align_up_int(value : Int, align : UInt64) -> Int {
  let a = align.to_int()
  if a <= 1 {
    return value
  }
  ((value + a - 1) / a) * a
}

///|
fn pie_serialize_merged_sections(sections : Array[@ir.MergedSection]) -> Bytes {
  let out : Array[Byte] = []
  for sec in sections {
    let aligned = pie_align_up_int(out.length(), sec.align)
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
    ir.input_objects[0].raw
  } else {
    pie_serialize_merged_sections(ir.merged_sections)
  }

  {
    bytes: payload,
    map_text: Some(
      "provisional \{opts.output_kind.to_string()} payload from \{ir.merged_sections.length()} merged sections",
    ),
  }
}
