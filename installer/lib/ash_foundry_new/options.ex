defmodule AshFoundryNew.Options do
  @moduledoc false

  @switches [
    recipe: :string,
    auth: :string,
    registration: :string,
    tenancy: :string,
    deploy: :string,
    module: :string,
    google_hosted_domain: :boolean,
    yes: :boolean
  ]

  @recipes ~w(internal saas personal custom)
  @deployments ~w(render fly none)

  @spec parse!([String.t()], (String.t() -> String.t() | nil)) :: {String.t(), keyword()}
  def parse!(argv, prompt \\ &IO.gets/1) do
    {options, positional} = OptionParser.parse!(argv, strict: @switches)

    app =
      case positional do
        [name] -> name
        _ -> Mix.raise("usage: mix ash_foundry.new APP_NAME [options]")
      end

    interactive? =
      options[:yes] != true and (is_nil(options[:recipe]) or is_nil(options[:deploy]))

    options = if interactive?, do: wizard(options, prompt), else: options
    normalized = normalize!(options)
    {app, normalized}
  end

  @spec flags(keyword()) :: [String.t()]
  def flags(options) do
    [
      "--recipe",
      options[:recipe],
      "--auth",
      options[:auth],
      "--registration",
      options[:registration],
      "--tenancy",
      options[:tenancy],
      "--deploy",
      options[:deploy],
      if(options[:google_hosted_domain],
        do: "--google-hosted-domain",
        else: "--no-google-hosted-domain"
      )
    ] ++ if(options[:module], do: ["--ash-foundry-module", options[:module]], else: [])
  end

  @spec command(String.t(), keyword()) :: String.t()
  def command(app, options) do
    OptionParser.to_argv(options, switches: @switches)
    |> then(fn argv -> ["mix", "ash_foundry.new", app | argv] end)
    |> Enum.map_join(" ", &quote_argument/1)
  end

  defp wizard(options, prompt) do
    IO.puts("\nAshFoundry creates an Ash-first Phoenix application. Press Enter for defaults.\n")

    recipe =
      options[:recipe] ||
        ask(prompt, "Recipe [internal/saas/personal/custom] (internal): ", "internal")

    defaults = recipe_defaults(recipe)

    auth = options[:auth] || ask(prompt, "Authentication (#{defaults.auth}): ", defaults.auth)

    registration =
      options[:registration] ||
        ask(
          prompt,
          "Registration [open/invite-only/closed] (#{defaults.registration}): ",
          defaults.registration
        )

    tenancy =
      options[:tenancy] ||
        ask(prompt, "Tenancy [none/organizations] (#{defaults.tenancy}): ", defaults.tenancy)

    deploy =
      options[:deploy] || ask(prompt, "Deployment [render/fly/none] (none): ", "none")

    hosted_domain =
      if String.contains?(auth, "google") do
        Keyword.get_lazy(options, :google_hosted_domain, fn ->
          answer =
            ask(
              prompt,
              "Require a Google hosted domain? [y/N]: ",
              if(defaults.hosted, do: "y", else: "n")
            )

          String.downcase(answer) in ["y", "yes"]
        end)
      else
        false
      end

    Keyword.merge(options,
      recipe: recipe,
      auth: auth,
      registration: registration,
      tenancy: tenancy,
      deploy: deploy,
      google_hosted_domain: hosted_domain
    )
  end

  defp normalize!(options) do
    recipe = require_enum!(options[:recipe], @recipes, "recipe")
    deploy = require_enum!(options[:deploy], @deployments, "deploy")
    defaults = recipe_defaults(recipe)

    auth = options[:auth] || defaults.auth
    registration = options[:registration] || defaults.registration
    tenancy = options[:tenancy] || defaults.tenancy

    if recipe == "custom" and
         Enum.any?([options[:auth], options[:registration], options[:tenancy]], &is_nil/1) do
      Mix.raise("custom recipe requires --auth, --registration, and --tenancy")
    end

    [
      recipe: recipe,
      auth: auth,
      registration: registration,
      tenancy: tenancy,
      deploy: deploy,
      module: options[:module],
      google_hosted_domain:
        String.contains?(auth, "google") and
          Keyword.get(options, :google_hosted_domain, defaults.hosted)
    ]
  end

  defp recipe_defaults("internal"),
    do: %{auth: "google", registration: "invite-only", tenancy: "none", hosted: true}

  defp recipe_defaults("saas"),
    do: %{auth: "google,password", registration: "open", tenancy: "organizations", hosted: false}

  defp recipe_defaults("personal"),
    do: %{auth: "password,magic-link", registration: "open", tenancy: "none", hosted: false}

  defp recipe_defaults("custom"),
    do: %{auth: "none", registration: "closed", tenancy: "none", hosted: false}

  defp recipe_defaults(other),
    do: Mix.raise("recipe must be one of #{Enum.join(@recipes, ", ")}; got #{inspect(other)}")

  defp require_enum!(nil, _allowed, name), do: Mix.raise("--#{name} is required")

  defp require_enum!(value, allowed, name) do
    if value in allowed,
      do: value,
      else: Mix.raise("#{name} must be one of #{Enum.join(allowed, ", ")}")
  end

  defp ask(prompt, message, default) do
    case prompt.(message) do
      nil -> Mix.raise("interactive input ended; rerun with complete CLI flags")
      answer -> answer |> String.trim() |> blank_default(default)
    end
  end

  defp blank_default("", default), do: default
  defp blank_default(value, _default), do: value

  defp quote_argument(argument) do
    if String.match?(argument, ~r/^[a-zA-Z0-9_.,:\/-]+$/) do
      argument
    else
      inspect(argument)
    end
  end
end
