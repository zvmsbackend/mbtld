///|
pub struct IoCursor {
  data : Bytes
  mut pos : Int
}

///|
pub fn IoCursor::new(data : Bytes) -> IoCursor {
  { data, pos: 0 }
}

///|
pub fn IoCursor::remaining(self : IoCursor) -> Int {
  self.data.length() - self.pos
}

///|
pub fn IoCursor::read_bytes(
  self : IoCursor,
  count : Int,
) -> Result[Bytes, String] {
  if self.remaining() < count {
    Err("unexpected end of data")
  } else {
    let result = self.data[self.pos:self.pos + count].to_bytes()
    self.pos = self.pos + count
    Ok(result)
  }
}

///|
pub fn IoCursor::read_u8(self : IoCursor) -> Result[Byte, String] {
  if self.remaining() < 1 {
    Err("unexpected end of data")
  } else {
    let b = self.data[self.pos]
    self.pos = self.pos + 1
    Ok(b)
  }
}

///|
pub fn IoCursor::read_u16_le(self : IoCursor) -> Result[UInt16, String] {
  if self.remaining() < 2 {
    Err("unexpected end of data")
  } else {
    let lo = self.data[self.pos].to_uint16()
    let hi = self.data[self.pos + 1].to_uint16()
    self.pos = self.pos + 2
    Ok(lo | (hi << 8))
  }
}

///|
pub fn IoCursor::read_u32_le(self : IoCursor) -> Result[UInt, String] {
  if self.remaining() < 4 {
    Err("unexpected end of data")
  } else {
    let b0 = self.data[self.pos].to_uint()
    let b1 = self.data[self.pos + 1].to_uint()
    let b2 = self.data[self.pos + 2].to_uint()
    let b3 = self.data[self.pos + 3].to_uint()
    self.pos = self.pos + 4
    Ok(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
  }
}

///|
pub fn IoCursor::read_u64_le(self : IoCursor) -> Result[UInt64, String] {
  if self.remaining() < 8 {
    Err("unexpected end of data")
  } else {
    let b0 = self.data[self.pos].to_uint64()
    let b1 = self.data[self.pos + 1].to_uint64()
    let b2 = self.data[self.pos + 2].to_uint64()
    let b3 = self.data[self.pos + 3].to_uint64()
    let b4 = self.data[self.pos + 4].to_uint64()
    let b5 = self.data[self.pos + 5].to_uint64()
    let b6 = self.data[self.pos + 6].to_uint64()
    let b7 = self.data[self.pos + 7].to_uint64()
    self.pos = self.pos + 8
    Ok(
      b0 |
      (b1 << 8) |
      (b2 << 16) |
      (b3 << 24) |
      (b4 << 32) |
      (b5 << 40) |
      (b6 << 48) |
      (b7 << 56),
    )
  }
}

///|
pub fn IoCursor::skip(self : IoCursor, count : Int) -> Unit {
  self.pos = self.pos + count
}

///|
pub fn IoCursor::position(self : IoCursor) -> Int {
  self.pos
}
