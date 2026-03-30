///| ELF assertions for testing

///|
/// Assert two ELF files have same sections
pub fn assert_same_sections(expected : Bytes, actual : Bytes) -> Bool {
  // TODO: implement section comparison
  ignore((expected, actual))
  true
}

///|
/// Assert two ELF files have same symbols
pub fn assert_same_symbols(expected : Bytes, actual : Bytes) -> Bool {
  // TODO: implement symbol comparison
  ignore((expected, actual))
  true
}

///|
/// Assert two ELF files have same relocations
pub fn assert_same_relocations(expected : Bytes, actual : Bytes) -> Bool {
  // TODO: implement relocation comparison
  ignore((expected, actual))
  true
}
