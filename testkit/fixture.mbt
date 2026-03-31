///| Test fixture loader

///|
/// Load a fixture file from testkit/fixtures directory
pub fn load_fixture(name : String) -> Bytes? {
  let path = "testkit/fixtures/\{name}"
  Some(@fs.read_file_to_bytes(path)) catch {
    @fs.IOError(_) => None
  }
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

  let star_count = count_stars(pattern)
  if star_count == 0 {
    return name == pattern
  }
  if star_count > 1 {
    return false
  }

  let idx = first_star_index(pattern)
  if idx < 0 {
    return name == pattern
  }
  let prefix = pattern[:idx].to_string()
  let suffix = pattern[idx + 1:].to_string()
  if name.length() < prefix.length() + suffix.length() {
    return false
  }
  starts_with(name, prefix) && ends_with(name, suffix)
}

///|
fn count_stars(s : String) -> Int {
  let mut count = 0
  for c in s {
    if c == '*' {
      count += 1
    }
  }
  count
}

///|
fn first_star_index(s : String) -> Int {
  let mut idx = 0
  for c in s {
    if c == '*' {
      return idx
    }
    idx += 1
  }
  -1
}

///|
fn starts_with(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  s[:prefix.length()].to_string() == prefix
}

///|
fn ends_with(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    return false
  }
  let start = s.length() - suffix.length()
  s[start:].to_string() == suffix
}
