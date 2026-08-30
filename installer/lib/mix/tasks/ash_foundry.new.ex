defmodule Mix.Tasks.AshFoundry.New do
  @moduledoc """
  Creates a production-oriented AshFoundry application.

      mix ash_foundry.new APP_NAME [options]

  ## Options

    * `--recipe` - internal, saas, personal, or custom
    * `--auth` - comma-separated google,password,magic-link or none
    * `--registration` - open, invite-only, or closed
    * `--tenancy` - none or organizations
    * `--deploy` - render, fly, or none
    * `--google-hosted-domain` / `--no-google-hosted-domain`
    * `--module` - application base module
    * `--yes` - require complete flags and do not prompt

  With no selection flags, a concise wizard shows every choice and prints the
  equivalent deterministic command before generation begins.
  """
  @shortdoc "Creates a new AshFoundry application"

  use Mix.Task

  alias AshFoundryNew.Options

  @impl Mix.Task
  def run(argv) do
    ensure_prerequisites!()
    {app, options} = Options.parse!(argv)
    destination = Path.expand(app)

    if File.exists?(destination) do
      Mix.raise("destination already exists: #{destination}")
    end

    IO.puts("\nEquivalent command:\n\n    #{Options.command(app, options)}\n")
    run_generator!(app, options)
    finalize_project!(destination)
    File.rm_rf!(Path.join(destination, ".git"))

    IO.puts("""

    AshFoundry created #{destination}

        cd #{app}
        mise install
        mise run setup
        mise run dev
    """)
  end

  defp run_generator!(app, options) do
    package =
      case System.get_env("ASH_FOUNDRY_PATH") do
        nil -> "ash_foundry@0.1.0"
        path -> "ash_foundry@path:#{Path.expand(path)}"
      end

    with_args =
      [
        "--no-ecto",
        "--no-assets",
        "--no-live",
        "--no-install",
        "--no-version-check",
        "--no-agents-md"
      ] ++
        if(options[:module], do: ["--module", options[:module]], else: [])

    args =
      [
        "igniter.new",
        app,
        "--with",
        "phx.new",
        "--with-args",
        Enum.map_join(with_args, " ", &quote_for_split/1),
        "--install",
        package,
        "--yes",
        "--no-git",
        "--no-installer-version-check"
      ] ++ Options.flags(options)

    case System.cmd("mix", args, into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {_output, status} -> Mix.raise("AshFoundry generation failed with exit status #{status}")
    end
  end

  defp ensure_prerequisites! do
    missing_archives =
      [
        {"phx.new", "mix archive.install hex phx_new 1.8.13"},
        {"igniter.new", "mix archive.install hex igniter_new 0.5.34"}
      ]
      |> Enum.reject(fn {task, _install} -> Mix.Task.get(task) end)

    if missing_archives != [] do
      instructions =
        Enum.map_join(missing_archives, "\n", fn {_task, install} -> "    #{install}" end)

      Mix.raise("required archives are missing:\n\n#{instructions}")
    end

    missing_executables = Enum.reject(~w(node pnpm mise), &System.find_executable/1)

    if missing_executables != [] do
      Mix.raise("required executables are missing: #{Enum.join(missing_executables, ", ")}")
    end
  end

  defp finalize_project!(destination) do
    run_project_command!(destination, "mix", ["ash.codegen", "--check"])
    run_project_command!(destination, "mix", ["format"])

    run_project_command!(destination, "pnpm", [
      "--dir",
      "assets",
      "install",
      "--no-frozen-lockfile"
    ])

    run_project_command!(destination, "pnpm", ["--dir", "assets", "run", "check:fix"])

    for script <- ~w(rel/overlays/bin/migrate rel/overlays/bin/server),
        path = Path.join(destination, script),
        File.exists?(path) do
      File.chmod!(path, 0o755)
    end
  end

  defp run_project_command!(destination, executable, arguments) do
    case System.cmd(executable, arguments,
           cd: destination,
           into: IO.stream(:stdio, :line),
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {_output, status} ->
        Mix.raise("#{executable} #{Enum.join(arguments, " ")} failed with exit status #{status}")
    end
  end

  defp quote_for_split(argument) do
    if String.contains?(argument, " "), do: inspect(argument), else: argument
  end
end
