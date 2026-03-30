///|
/// Archive header size in bytes
pub const AR_HEADER_SIZE : Int = 60

///|
/// Read archive file and extract members
pub fn read_archive(
  data : Bytes,
  path : String,
) -> Array[ArchiveMember] raise ElfError {
  let view = data[:]
  if view.length() < 8 {
    raise TruncatedFile("archive too small: \{path}")
  }
  // Check archive magic "!<arch>\n"
  if view[0] != '!' ||
    view[1] != '<' ||
    view[2] != 'a' ||
    view[3] != 'r' ||
    view[4] != 'c' ||
    view[5] != 'h' ||
    view[6] != '>' ||
    view[7] != '\n' {
    raise CorruptArchive("invalid archive magic: \{path}")
  }

  let members : Array[ArchiveMember] = []
  let mut pos = 8
  while pos + AR_HEADER_SIZE <= view.length() {
    // Parse archive member header
    // Format: name (16 bytes) + date (12) + uid (6) + gid (6) + mode (8) + size (10) + fmag (2)
    let mut name_end = pos
    while name_end < pos + 16 && view[name_end] != ' ' && view[name_end] != '/' {
      name_end = name_end + 1
    }
    let name = view[pos:name_end].to_string().trim().to_string()

    // Size is at offset 48, 10 bytes decimal
    let size_str = view[pos + 48:pos + 58].to_string().trim()
    let size = @string.parse_uint(size_str).reinterpret_as_int() catch {
      _ => raise CorruptArchive("invalid archive member size: \{path}")
    }

    let content_start = pos + AR_HEADER_SIZE
    let content_end = content_start + size
    if content_end > view.length() {
      raise CorruptArchive("archive member truncated: \{path}")
    }

    let member_data = view[content_start:content_end].to_bytes()
    members.push({ name, data: member_data })

    // Move to next member (aligned to 2 bytes)
    pos = content_end
    if pos % 2 == 1 {
      pos = pos + 1
    }
  }
  members
}

///|
/// Check if bytes start with archive magic
pub fn is_archive_magic(data : BytesView) -> Bool {
  data.length() >= 8 &&
  data[0] == '!' &&
  data[1] == '<' &&
  data[2] == 'a' &&
  data[3] == 'r' &&
  data[4] == 'c' &&
  data[5] == 'h' &&
  data[6] == '>' &&
  data[7] == '\n'
}
