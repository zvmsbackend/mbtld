///|
pub fn read_cstring(data : BytesView, offset : UInt) -> String {
  let buf = StringBuilder::new()
  for pos in offset.reinterpret_as_int()..<data.length() {
    let b = data[pos]
    if b == 0 {
      break
    }
    buf.write_char(b.to_char())
  }
  buf.to_string()
}
