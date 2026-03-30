///|
pub fn read_u8(data : BytesView, offset : Int) -> Byte {
  data[offset]
}

///|
pub fn read_u16_le(data : BytesView, offset : Int) -> UInt16 {
  data[offset].to_uint16() | (data[offset + 1].to_uint16() << 8)
}

///|
pub fn read_u32_le(data : BytesView, offset : Int) -> UInt {
  data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)
}

///|
pub fn read_u64_le(data : BytesView, offset : Int) -> UInt64 {
  data[offset].to_uint64() |
  (data[offset + 1].to_uint64() << 8) |
  (data[offset + 2].to_uint64() << 16) |
  (data[offset + 3].to_uint64() << 24) |
  (data[offset + 4].to_uint64() << 32) |
  (data[offset + 5].to_uint64() << 40) |
  (data[offset + 6].to_uint64() << 48) |
  (data[offset + 7].to_uint64() << 56)
}

///|
pub fn read_i16_le(data : BytesView, offset : Int) -> Int16 {
  Int16::from_byte(data[offset]) | (Int16::from_byte(data[offset + 1]) << 8)
}

///|
pub fn read_i32_le(data : BytesView, offset : Int) -> Int {
  data[offset].to_int() |
  (data[offset + 1].to_int() << 8) |
  (data[offset + 2].to_int() << 16) |
  (data[offset + 3].to_int() << 24)
}

///|
pub fn read_i64_le(data : BytesView, offset : Int) -> Int64 {
  data[offset].to_int64() |
  (data[offset + 1].to_int64() << 8) |
  (data[offset + 2].to_int64() << 16) |
  (data[offset + 3].to_int64() << 24) |
  (data[offset + 4].to_int64() << 32) |
  (data[offset + 5].to_int64() << 40) |
  (data[offset + 6].to_int64() << 48) |
  (data[offset + 7].to_int64() << 56)
}
