if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshFoundry.Install do
    @moduledoc "Installs an AshFoundry recipe into a newly generated Phoenix project."
    @shortdoc "Installs the selected AshFoundry recipe"

    use Igniter.Mix.Task

    alias AshFoundry.{Generator, Plan}

    @base_installs [
      {:ash, "== 3.32.1"},
      {:ash_postgres, "== 2.12.0"},
      {:ash_phoenix, "== 2.3.24"}
    ]
    @auth_installs [
      {:ash_authentication, "== 4.14.2"},
      {:ash_authentication_phoenix, "== 2.17.3"}
    ]

    @impl Igniter.Mix.Task
    def info(argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash_foundry,
        example:
          "mix igniter.install ash_foundry --recipe internal --deploy render --yes-to-deps",
        positional: [],
        schema: [
          recipe: :string,
          auth: :string,
          registration: :string,
          tenancy: :string,
          deploy: :string,
          module: :string,
          ash_foundry_module: :string,
          google_hosted_domain: :boolean
        ],
        defaults: [],
        aliases: [],
        required: [],
        composes: [],
        installs:
          @base_installs ++
            if(Plan.auth_enabled?(install_options(argv)), do: @auth_installs, else: []),
        adds_deps: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app = Mix.Project.config() |> Keyword.fetch!(:app) |> Atom.to_string()
      plan = Plan.build!(app, igniter.args.options)
      Generator.generate(igniter, plan)
    end

    defp install_options(argv) do
      {options, _remaining, _invalid} =
        OptionParser.parse(argv,
          strict: [
            recipe: :string,
            auth: :string,
            registration: :string,
            tenancy: :string,
            deploy: :string,
            module: :string,
            ash_foundry_module: :string,
            google_hosted_domain: :boolean,
            yes: :boolean,
            yes_to_deps: :boolean
          ]
        )

      options
    end
  end
else
  defmodule Mix.Tasks.AshFoundry.Install do
    @moduledoc false
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.raise("ash_foundry.install requires Igniter; run mix igniter.install ash_foundry")
    end
  end
end
