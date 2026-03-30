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
/// Create error diagnostic
pub fn error(code : String, message : String) -> Diagnostic {
  { level: Error, code, message, file: None, section: None, symbol: None }
}

///|
/// Create warning diagnostic
pub fn warning(code : String, message : String) -> Diagnostic {
  { level: Warning, code, message, file: None, section: None, symbol: None }
}

///|
/// Create info diagnostic
pub fn info(code : String, message : String) -> Diagnostic {
  { level: Info, code, message, file: None, section: None, symbol: None }
}
