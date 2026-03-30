///| Build IR from input objects

///|
/// Build intermediate representation from inputs
pub fn build_ir(
  inputs : Array[@ir.InputObject],
  opts : @ir.LinkOptions,
) -> @ir.LinkIr {
  ignore(inputs)
  ignore(opts)
  {
    arch: X86_64,
    bitness: ELF64,
    merged_sections: [],
    merged_symbols: [],
    pending_relocs: [],
  }
}
