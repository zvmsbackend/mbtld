///|
pub fn align_up(value : UInt64, alignment : UInt64) -> UInt64 {
  if alignment == 0 {
    value
  } else {
    let mask = alignment - 1
    (value + mask) & mask.lnot()
  }
}

///|
pub fn align_down(value : UInt64, alignment : UInt64) -> UInt64 {
  if alignment == 0 {
    value
  } else {
    value & (alignment - 1).lnot()
  }
}

///|
pub fn is_aligned(value : UInt64, alignment : UInt64) -> Bool {
  alignment == 0 || (value & (alignment - 1)) == 0
}
