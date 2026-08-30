defmodule AshFoundry.Selection do
  @moduledoc "Canonical recipe defaults, CLI parsing, and combination rules."

  @recipes [:internal, :saas, :personal, :custom]
  @auth_methods [:google, :password, :magic_link]
  @registrations [:open, :invite_only, :closed]
  @tenancies [:none, :organizations]
  @deployments [:render, :fly, :none]
  @default_session_absolute_minutes 30 * 24 * 60
  @default_session_idle_minutes 12 * 60

  @type recipe :: :internal | :saas | :personal | :custom
  @type auth_method :: :google | :password | :magic_link
  @type registration :: :open | :invite_only | :closed
  @type tenancy :: :none | :organizations
  @type deployment :: :render | :fly | :none
  @type organization_creation :: :none | :open | :system_admin

  @spec recipes() :: [recipe()]
  def recipes, do: @recipes

  @spec auth_methods() :: [auth_method()]
  def auth_methods, do: @auth_methods

  @spec registrations() :: [registration()]
  def registrations, do: @registrations

  @spec tenancies() :: [tenancy()]
  def tenancies, do: @tenancies

  @spec deployments() :: [deployment()]
  def deployments, do: @deployments

  @spec defaults(recipe()) :: map()
  def defaults(:internal) do
    %{
      auth: [:google],
      registration: :invite_only,
      tenancy: :none,
      google_hosted_domain: true,
      session_absolute_minutes: 12 * 60,
      session_idle_minutes: 30
    }
  end

  def defaults(:saas) do
    %{
      auth: [:google, :password],
      registration: :open,
      tenancy: :organizations,
      google_hosted_domain: false,
      session_absolute_minutes: @default_session_absolute_minutes,
      session_idle_minutes: @default_session_idle_minutes
    }
  end

  def defaults(:personal) do
    %{
      auth: [:password, :magic_link],
      registration: :open,
      tenancy: :none,
      google_hosted_domain: false,
      session_absolute_minutes: @default_session_absolute_minutes,
      session_idle_minutes: @default_session_idle_minutes
    }
  end

  def defaults(:custom) do
    %{
      google_hosted_domain: false,
      session_absolute_minutes: @default_session_absolute_minutes,
      session_idle_minutes: @default_session_idle_minutes
    }
  end

  @doc "True when the CLI selection will generate authentication."
  @spec auth_enabled?(keyword()) :: boolean()
  def auth_enabled?(options) when is_list(options) do
    case {options[:auth], options[:recipe]} do
      {auth, _} when auth in ["none", :none] ->
        false

      {nil, recipe} when recipe in ["custom", :custom] ->
        false

      {nil, _recipe} ->
        true

      {auth, _recipe} ->
        case auth(auth, %{}, :custom) do
          {:ok, methods} -> methods != []
          {:error, _} -> true
        end
    end
  end

  @spec auth(term(), map(), recipe()) :: {:ok, [auth_method()]} | {:error, String.t()}
  def auth(nil, _defaults, :custom),
    do: {:error, "custom recipe requires --auth (google,password,magic-link, or none)"}

  def auth(nil, defaults, _recipe), do: {:ok, defaults.auth}
  def auth("none", _defaults, _recipe), do: {:ok, []}
  def auth(:none, _defaults, _recipe), do: {:ok, []}

  def auth(value, _defaults, _recipe) when is_binary(value) do
    methods =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&(&1 |> String.replace("-", "_") |> String.to_existing_atom()))
      |> Enum.uniq()

    if methods != [] and Enum.all?(methods, &(&1 in @auth_methods)) do
      {:ok, methods}
    else
      {:error, "auth must be a comma-separated subset of google,password,magic-link or none"}
    end
  rescue
    ArgumentError ->
      {:error, "auth must be a comma-separated subset of google,password,magic-link or none"}
  end

  def auth(value, _defaults, _recipe) when is_list(value) do
    if value != [] and Enum.all?(value, &(&1 in @auth_methods)) do
      {:ok, Enum.uniq(value)}
    else
      {:error, "invalid auth selection"}
    end
  end

  @spec selected(keyword(), map(), recipe(), atom(), [atom()]) ::
          {:ok, atom()} | {:error, String.t()}
  def selected(options, _defaults, :custom, key, allowed) do
    case options[key] do
      nil -> {:error, "custom recipe requires --#{dashed(key)}"}
      value -> enum(value, allowed, Atom.to_string(key))
    end
  end

  def selected(options, defaults, _recipe, key, allowed),
    do: enum(options[key] || defaults[key], allowed, Atom.to_string(key))

  @spec enum(term(), [atom()], String.t()) :: {:ok, atom()} | {:error, String.t()}
  def enum(nil, _allowed, name), do: {:error, "--#{dashed(name)} is required"}

  def enum(value, allowed, name) when is_atom(value) do
    if value in allowed do
      {:ok, value}
    else
      {:error, "#{name} must be one of #{Enum.map_join(allowed, ", ", &dashed/1)}"}
    end
  end

  def enum(value, allowed, name) when is_binary(value) do
    normalized = String.replace(value, "-", "_")

    case Enum.find(allowed, &(Atom.to_string(&1) == normalized)) do
      nil -> {:error, "#{name} must be one of #{Enum.map_join(allowed, ", ", &dashed/1)}"}
      match -> {:ok, match}
    end
  end

  def enum(_value, allowed, name),
    do: {:error, "#{name} must be one of #{Enum.map_join(allowed, ", ", &dashed/1)}"}

  @spec validate_combination([auth_method()], registration(), tenancy(), keyword()) ::
          :ok | {:error, String.t()}
  def validate_combination([], _registration, :organizations, _options),
    do: {:error, "no-auth applications do not support organization tenancy"}

  def validate_combination([], registration, _tenancy, _options) when registration != :closed,
    do: {:error, "no-auth applications require --registration closed"}

  def validate_combination(auth, _registration, _tenancy, options) do
    if options[:google_hosted_domain] == true and :google not in auth do
      {:error, "--google-hosted-domain requires google authentication"}
    else
      :ok
    end
  end

  @spec hosted_domain?(keyword(), map(), [auth_method()]) :: boolean()
  def hosted_domain?(options, defaults, auth) do
    :google in auth and
      Keyword.get(options, :google_hosted_domain, defaults[:google_hosted_domain] || false)
  end

  @spec organization_creation(recipe(), tenancy()) :: organization_creation()
  def organization_creation(_recipe, :none), do: :none
  def organization_creation(:saas, :organizations), do: :open
  def organization_creation(_recipe, :organizations), do: :system_admin

  @spec session_minutes(map()) :: {pos_integer(), pos_integer()}
  def session_minutes(defaults) do
    {
      defaults[:session_absolute_minutes] || @default_session_absolute_minutes,
      defaults[:session_idle_minutes] || @default_session_idle_minutes
    }
  end

  @spec dashed(atom() | String.t()) :: String.t()
  def dashed(value) when is_atom(value), do: value |> Atom.to_string() |> dashed()
  def dashed(value) when is_binary(value), do: String.replace(value, "_", "-")
end
