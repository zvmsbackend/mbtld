///| Test fixture loader

///|
/// Load a fixture file from testkit/fixtures directory
pub fn load_fixture(name : String) -> Bytes? {
  let path = "testkit/fixtures/\{name}"
  (try? @fs.read_file_to_bytes(path)).to_option()
}

///|
/// Load all fixtures matching a pattern
pub fn load_fixtures(pattern : String) -> Array[(String, Bytes)] {
  let entries = @fs.read_dir("testkit/fixtures") catch {
    @fs.IOError(_) => return []
  }

  let out : Array[(String, Bytes)] = []
  for entry in entries {
    if !matches_pattern(entry, pattern) {
      continue
    }
    let path = "testkit/fixtures/\{entry}"
    let is_file = @fs.is_file(path) catch { @fs.IOError(_) => false }
    if !is_file {
      continue
    }
    try {
      let data = @fs.read_file_to_bytes(path)
      out.push((entry, data))
    } catch {
      @fs.IOError(_) => ()
    }
  }
  out
}

///|
fn matches_pattern(name : String, pattern : String) -> Bool {
  if pattern == "*" {
    return true
  }

  let star_count = pattern.iter().filter(c => c == '*').count()
  if star_count == 0 {
    return name == pattern
  }
  if star_count > 1 {
    return false
  }

  guard pattern.iter().search_by(c => c == '*') is Some(idx) else {
    return name == pattern
  }
  let prefix = pattern[:idx].to_string()
  let suffix = pattern[idx + 1:].to_string()
  if name.length() < prefix.length() + suffix.length() {
    return false
  }
  name.has_prefix(prefix) && name.has_suffix(suffix)
}

///|
fn[T] Iter::search_by(self : Iter[T], f : (T) -> Bool) -> Int? {
  for item in self; idx = 0 {
    if f(item) {
      return Some(idx)
    }
    continue idx + 1
  }
  None
}
