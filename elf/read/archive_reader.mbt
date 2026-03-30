///|
/// Read archive file and extract members
pub fn read_archive(
  data : Bytes,
  path : String,
) -> Array[ArchiveMember] raise ElfError {
  let view = data[:]
  if view.length() < 8 {
    raise ElfError::TruncatedFile("archive too small: \{path}")
  }
  if view[0] != '!' ||
    view[1] != '<' ||
    view[2] != 'a' ||
    view[3] != 'r' ||
    view[4] != 'c' ||
    view[5] != 'h' ||
    view[6] != '>' ||
    view[7] != '\n' {
    raise ElfError::CorruptArchive("invalid archive magic: \{path}")
  }
  let members : Array[ArchiveMember] = []
  let mut pos = 8
  while pos < view.length() {
    if pos + 60 > view.length() {
      break
    }
    let mut i = pos
    while i < pos + 16 && view[i] != ' ' && view[i] != '/' {
      i += 1
    }
    let name = view[pos:i].to_string().trim()
    let size_str = view[pos + 48:pos + 58].to_string().trim()
    let size = @string.parse_uint(size_str).reinterpret_as_int() catch {
      _ =>
        raise ElfError::CorruptArchive("invalid archive member size: \{path}")
    }
    let content_start = pos + 60
    let content_end = content_start + size
    if content_end > view.length() {
      raise ElfError::CorruptArchive("archive member truncated: \{path}")
    }
    let member_data = view[content_start:content_end].to_bytes()
    members.push({ name: name.to_string(), data: member_data })
    pos = content_end
    if pos % 2 == 1 {
      pos += 1
    }
  }
  members
}
