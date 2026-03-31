///|
/// Architecture enumeration
pub(all) enum Arch {
  X86_64
  AARCH64
  RISCV64
  LOONGARCH64
} derive(Show, Eq)

///|
/// Bitness enumeration
pub(all) enum Bitness {
  ELF32
  ELF64
} derive(Show, Eq)

///|
/// Output kind enumeration
pub(all) enum OutputKind {
  Relocatable
  ExecutablePie
  SharedLibrary
  EfiApplication
  EfiBootDriver
  EfiRuntimeDriver
} derive(Show, Eq)

///|
/// Symbol binding
pub(all) enum SymbolBinding {
  Local
  Global
  Weak
} derive(Show, Eq)

///|
/// Symbol type
pub(all) enum SymbolType {
  NoType
  Object
  Func
  Section
  File
  Tls
} derive(Show, Eq)

///|
/// Visibility
pub(all) enum Visibility {
  Default
  Hidden
  Protected
  Internal
} derive(Show, Eq)

///|
/// Input object representation
pub(all) struct InputObject {
  path : String
  raw : Bytes
  arch : Arch
  bitness : Bitness
  sections : Array[SectionRec]
  symbols : Array[SymbolRec]
  relocs : Array[RelocRec]
} derive(Show)

///|
/// Section record
pub(all) struct SectionRec {
  name : String
  name_hash : UInt64
  ty : UInt
  flags : UInt64
  align : UInt64
  data : Bytes
  info : UInt
  link : UInt
} derive(Show)

///|
/// Symbol record
pub(all) struct SymbolRec {
  name : String
  name_hash : UInt64
  binding : SymbolBinding
  ty : SymbolType
  vis : Visibility
  sec_index : Int
  value : UInt64
  size : UInt64
} derive(Show)

///|
/// Relocation record
pub(all) struct RelocRec {
  sec_index : Int
  offset : UInt64
  rel_type : UInt
  sym_index : Int
  addend : Int64
  has_addend : Bool
} derive(Show)

///|
/// Linker IR (Intermediate Representation)
pub(all) struct LinkIr {
  arch : Arch
  bitness : Bitness
  input_objects : Array[InputObject]
  merged_sections : Array[MergedSection]
  merged_symbols : Array[MergedSymbol]
  pending_relocs : Array[PendingReloc]
} derive(Show)

///|
/// Merged section
pub(all) struct MergedSection {
  output_name : String
  output_index : Int
  align : UInt64
  bytes : Bytes
} derive(Show)

///|
/// Merged symbol
pub(all) struct MergedSymbol {
  name : String
  output_sec : Int
  output_value : UInt64
  binding : SymbolBinding
  ty : SymbolType
  vis : Visibility
} derive(Show)

///|
/// Pending relocation
pub(all) struct PendingReloc {
  out_sec : Int
  patch_off : UInt64
  rel_type : UInt
  target_sym : Int
  addend : Int64
} derive(Show)

///|
/// Link options
pub(all) struct LinkOptions {
  output : String
  output_kind : OutputKind
  entry : String
  input_files : Array[String]
  dynamic_libs : Array[String]
  dynamic_linker : String?
  strip_symbols : Bool
  strip_debug : Bool
  no_default_lib : Bool
  smart_linking : Bool
  section_align : UInt
  start_address : UInt64
  verbose : Bool
} derive(Show)

///|
/// Link artifact (output)
pub(all) struct LinkArtifact {
  bytes : Bytes
  map_text : String?
} derive(Show)
