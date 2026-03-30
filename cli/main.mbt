///|
/// CLI main entry point
fn main {
  let args = @sys.get_cli_args()
  @sys.exit(run_cli(args))
}
