defmodule AshFoundryNew.Options do
  @moduledoc false

  alias AshFoundryNew.Selection

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

  @spec parse!([String.t()], (String.t() -> String.t() | nil)) :: {String.t(), keyword()}
  def parse!(argv, prompt \\ &IO.gets/1) do
    {options, positional} = OptionParser.parse!(argv, strict: @switches)

    app =
      case positional do
        [name] -> name
        _ -> Mix.raise("usage: mix ash_foundry.new APP_NAME [options]")
      end

    options = if interactive?(options), do: wizard(options, prompt), else: options
    {app, normalize!(options)}
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

  defp interactive?(options) do
    options[:yes] != true and
      (is_nil(options[:recipe]) or is_nil(options[:deploy]) or custom_incomplete?(options))
  end

  defp custom_incomplete?(options) do
    options[:recipe] == "custom" and
      Enum.any?([options[:auth], options[:registration], options[:tenancy]], &is_nil/1)
  end

  defp wizard(options, prompt) do
    IO.puts("\nAshFoundry creates an Ash-first Phoenix application. Press Enter for defaults.\n")

    recipe =
      options[:recipe] ||
        ask(prompt, "Recipe [internal/saas/personal/custom] (internal): ", "internal")

    defaults = Selection.wizard_defaults(recipe)

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
    recipe = unwrap!(Selection.enum(options[:recipe], Selection.recipes(), "recipe"))
    deploy = unwrap!(Selection.enum(options[:deploy], Selection.deployments(), "deploy"))
    defaults = Selection.wizard_defaults(Atom.to_string(recipe))

    auth = options[:auth] || defaults.auth
    registration = options[:registration] || defaults.registration
    tenancy = options[:tenancy] || defaults.tenancy

    if recipe == :custom and
         Enum.any?([options[:auth], options[:registration], options[:tenancy]], &is_nil/1) do
      Mix.raise("custom recipe requires --auth, --registration, and --tenancy")
    end

    parsed_auth = unwrap!(Selection.auth(auth))

    parsed_registration =
      unwrap!(Selection.enum(registration, Selection.registrations(), "registration"))

    parsed_tenancy = unwrap!(Selection.enum(tenancy, Selection.tenancies(), "tenancy"))

    hosted =
      String.contains?(auth, "google") and
        Keyword.get(options, :google_hosted_domain, defaults.hosted)

    unwrap!(
      Selection.validate_combination(
        parsed_auth,
        parsed_registration,
        parsed_tenancy,
        options[:google_hosted_domain] == true
      )
    )

    [
      recipe: Atom.to_string(recipe),
      auth: auth,
      registration: registration,
      tenancy: tenancy,
      deploy: Atom.to_string(deploy),
      module: options[:module],
      google_hosted_domain: hosted
    ]
  end

  defp unwrap!({:ok, value}), do: value
  defp unwrap!({:error, message}), do: Mix.raise(message)
  defp unwrap!(:ok), do: :ok

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
