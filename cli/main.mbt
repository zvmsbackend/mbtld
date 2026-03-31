///|
/// CLI main entry point
fn main {
  let args = @sys.get_cli_args()
  @sys.exit(args |> run_cli)
}
