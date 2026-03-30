///|
pub fn read_cstring(data : BytesView, offset : UInt) -> String {
  let buf = StringBuilder::new()
  for pos = offset.reinterpret_as_int(); pos < data.length(); pos = pos + 1 {
    let b = data[pos]
    if b == 0 {
      break
    }
    buf.write_char(b.to_char())
  }
  buf.to_string()
}
