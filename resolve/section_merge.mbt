///| Section merging logic

///|
/// Get or create output section for input section
pub fn get_output_section(sec_name : String) -> String {
  let name = sec_name.trim().to_string()
  if name.has_prefix(".text") {
    ".text"
  } else if name.has_prefix(".rodata") {
    ".rodata"
  } else if name.has_prefix(".data") {
    ".data"
  } else if name.has_prefix(".bss") {
    ".bss"
  } else {
    name
  }
}

///|
/// Calculate section order for output
pub fn section_order(name : String) -> Int {
  let name = name.trim()
  if name == ".text" {
    100
  } else if name.has_prefix(".text") {
    110
  } else if name == ".rodata" {
    200
  } else if name.has_prefix(".rodata") {
    210
  } else if name == ".data" {
    300
  } else if name.has_prefix(".data") {
    310
  } else if name == ".bss" {
    400
  } else if name.has_prefix(".bss") {
    410
  } else {
    500
  }
}
