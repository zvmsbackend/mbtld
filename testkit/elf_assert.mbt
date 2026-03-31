///| ELF assertions for testing

///|
/// Assert two ELF files have same sections
pub fn assert_same_sections(expected : Bytes, actual : Bytes) -> Bool {
  let expected_obj = parse_for_assert(expected)
  let actual_obj = parse_for_assert(actual)
  match (expected_obj, actual_obj) {
    (Some(e), Some(a)) => {
      if e.sections.length() != a.sections.length() {
        return false
      }
      for idx in 0..<e.sections.length() {
        let es = e.sections[idx]
        let act_sec = a.sections[idx]
        if es.name != act_sec.name ||
          es.sh_type != act_sec.sh_type ||
          es.sh_flags != act_sec.sh_flags ||
          es.sh_size != act_sec.sh_size ||
          es.data != act_sec.data {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
/// Assert two ELF files have same symbols
pub fn assert_same_symbols(expected : Bytes, actual : Bytes) -> Bool {
  let expected_obj = parse_for_assert(expected)
  let actual_obj = parse_for_assert(actual)
  match (expected_obj, actual_obj) {
    (Some(e), Some(a)) => {
      if e.symbols.length() != a.symbols.length() {
        return false
      }
      for idx in 0..<e.symbols.length() {
        let es = e.symbols[idx]
        let act_sym = a.symbols[idx]
        if es.name != act_sym.name ||
          es.st_info != act_sym.st_info ||
          es.st_other != act_sym.st_other ||
          es.st_shndx != act_sym.st_shndx ||
          es.st_value != act_sym.st_value ||
          es.st_size != act_sym.st_size {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
/// Assert two ELF files have same relocations
pub fn assert_same_relocations(expected : Bytes, actual : Bytes) -> Bool {
  let expected_obj = parse_for_assert(expected)
  let actual_obj = parse_for_assert(actual)
  match (expected_obj, actual_obj) {
    (Some(e), Some(a)) => {
      if e.relocations.length() != a.relocations.length() {
        return false
      }
      for idx in 0..<e.relocations.length() {
        let er = e.relocations[idx]
        let ar = a.relocations[idx]
        if er.section_name != ar.section_name ||
          er.r_offset != ar.r_offset ||
          er.r_info != ar.r_info ||
          er.r_addend != ar.r_addend ||
          er.has_addend != ar.has_addend {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn parse_for_assert(data : Bytes) -> @read.ParsedObject? {
  Some(@read.parse_object(data, "<assert>")) catch {
    _ => None
  }
}
