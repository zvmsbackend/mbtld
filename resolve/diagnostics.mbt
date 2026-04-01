///|
/// Diagnostic level
pub enum DiagLevel {
  Error
  Warning
  Info
} derive(Show, Eq)

///|
/// Diagnostic message
pub struct Diagnostic {
  level : DiagLevel
  code : String
  message : String
  file : String?
  section : String?
  symbol : String?
} derive(Show)

///|
/// Create error diagnostic with optional location fields
pub fn error_at(
  code : String,
  message : String,
  file? : String,
  section? : String,
  symbol? : String,
) -> Diagnostic {
  { level: Error, code, message, file, section, symbol }
}

///|
/// Create warning diagnostic with optional location fields
pub fn warning_at(
  code : String,
  message : String,
  file? : String,
  section? : String,
  symbol? : String,
) -> Diagnostic {
  { level: Warning, code, message, file, section, symbol }
}

///|
/// Create info diagnostic with optional location fields
pub fn info_at(
  code : String,
  message : String,
  file? : String,
  section? : String,
  symbol? : String,
) -> Diagnostic {
  { level: Info, code, message, file, section, symbol }
}

///|
/// Create error diagnostic
pub fn error(code : String, message : String) -> Diagnostic {
  error_at(code, message)
}

///|
/// Create warning diagnostic
pub fn warning(code : String, message : String) -> Diagnostic {
  warning_at(code, message)
}

///|
/// Create info diagnostic
pub fn info(code : String, message : String) -> Diagnostic {
  info_at(code, message)
}
