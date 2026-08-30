defmodule AshFoundry.Generator do
  @moduledoc false

  alias AshFoundry.{Plan, Template}
  alias Igniter.Project.Deps

  @common_deps [
    {:phoenix, "== 1.8.13"},
    {:phoenix_ecto, "== 4.7.0"},
    {:ash, "== 3.32.1"},
    {:ash_postgres, "== 2.12.0"},
    {:ash_phoenix, "== 2.3.24"},
    {:picosat_elixir, "== 0.2.3"},
    {:oban, "== 2.24.0"},
    {:inertia, "== 2.6.2"},
    {:phoenix_vite, "== 0.5.1"},
    {:swoosh, "== 1.28.0"},
    {:gen_smtp, "== 1.3.0"},
    {:req, "== 0.7.4"},
    {:sentry, "== 13.5.0"},
    {:hammer, "== 7.4.1"},
    {:logger_json, "== 7.0.4"},
    {:telemetry_metrics_prometheus_core, "== 1.2.1"},
    {:tidewave, "== 0.9.0", [only: :dev]},
    {:credo, "== 1.7.19", [only: [:dev, :test], runtime: false]},
    {:dialyxir, "== 1.4.7", [only: [:dev, :test], runtime: false]},
    {:mix_audit, "== 2.1.5", [only: [:dev, :test], runtime: false]},
    {:sobelow, "== 0.15.0", [only: [:dev, :test], runtime: false]}
  ]

  @auth_deps [
    {:ash_authentication, "== 4.14.2"},
    {:ash_authentication_phoenix, "== 2.17.3"},
    {:argon2_elixir, "== 4.1.3"}
  ]

  @superseded_phoenix_files [
    "lib/__app___web/components/core_components.ex",
    "lib/__app___web/controllers/page_html.ex",
    "lib/__app___web/controllers/page_html/home.html.heex",
    "test/__app___web/controllers/page_controller_test.exs"
  ]

  @doc "Writes the selected application template after the official installers have run."
  @spec generate(Igniter.t(), Plan.t()) :: Igniter.t()
  def generate(igniter, plan) do
    igniter
    |> add_dependencies(plan)
    |> write_templates(plan)
    |> remove_superseded_phoenix_files(plan)
    |> remove_custom_module_installer_files(plan)
    |> Igniter.create_new_file(".ash_foundry.exs", Plan.provenance(plan), on_exists: :overwrite)
    |> Igniter.add_notice(completion_notice(plan))
  end

  defp add_dependencies(igniter, plan) do
    deps = if plan.auth == [], do: @common_deps, else: @common_deps ++ @auth_deps

    Enum.reduce(deps, igniter, fn dependency, acc ->
      Deps.add_dep(acc, normalize_dependency(dependency),
        on_exists: :overwrite,
        yes?: true
      )
    end)
  end

  defp normalize_dependency({name, requirement, options}), do: {name, requirement, options}
  defp normalize_dependency({name, requirement}), do: {name, requirement}

  defp remove_superseded_phoenix_files(igniter, plan) do
    Enum.reduce(@superseded_phoenix_files, igniter, fn path, acc ->
      path = String.replace(path, "__app__", plan.app)

      if Igniter.exists?(acc, path), do: Igniter.rm(acc, path), else: acc
    end)
  end

  defp remove_custom_module_installer_files(igniter, plan) do
    if Macro.underscore(plan.module) == plan.app do
      igniter
    else
      template_root = template_root()

      plan
      |> template_sources(template_root)
      |> Enum.map(fn source ->
        {
          relative_target(source, template_root, plan.app),
          relative_target(source, template_root, Macro.underscore(plan.module))
        }
      end)
      |> Enum.reject(fn {installer_target, module_target} ->
        installer_target == module_target
      end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.reduce(igniter, &remove_file(&2, &1))
    end
  end

  defp remove_file(igniter, path) do
    if Igniter.exists?(igniter, path), do: Igniter.rm(igniter, path), else: igniter
  end

  defp write_templates(igniter, plan) do
    template_root = template_root()

    plan
    |> template_sources(template_root)
    |> Enum.reduce(igniter, fn source, acc ->
      relative = relative_target(source, template_root, Macro.underscore(plan.module))
      contents = Template.render(source, plan)

      if String.trim(contents) == "" do
        remove_file(acc, relative)
      else
        Igniter.create_new_file(acc, relative, contents, on_exists: :overwrite)
      end
    end)
  end

  @doc false
  @spec template_groups(Plan.t()) :: [String.t()]
  def template_groups(plan) do
    groups = ["common", if(plan.auth == [], do: "no_auth", else: "auth")]
    groups = if(plan.tenancy == :organizations, do: groups ++ ["tenancy"], else: groups)

    if plan.deploy == :none,
      do: groups,
      else: groups ++ ["deploy_common", "deploy_#{plan.deploy}"]
  end

  defp template_sources(plan, template_root) do
    plan
    |> template_groups()
    |> Enum.flat_map(&files(Path.join(template_root, &1)))
    |> Enum.sort()
  end

  defp files(directory) do
    directory
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
  end

  defp relative_target(source, root, app_path) do
    source
    |> Path.relative_to(root)
    |> String.split("/", parts: 2)
    |> List.last()
    |> String.replace("__app__", app_path)
    |> String.trim_trailing(".template")
  end

  defp template_root do
    :ash_foundry
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("templates")
  end

  defp completion_notice(plan) do
    """
    AshFoundry #{AshFoundry.version()} installed the #{plan.recipe} recipe.

    Review .ash_foundry.exs and the generated security/deployment runbook, then run:

        mise install
        mise run setup
        mise run check

    External providers remain disabled until their runtime credentials are configured.
    """
  end
end
