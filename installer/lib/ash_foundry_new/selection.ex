defmodule AshFoundryNew.Selection do
  @moduledoc "Archive-side copy of AshFoundry.Selection. Kept in lockstep by contract tests."

  @recipes [:internal, :saas, :personal, :custom]
  @auth_methods [:google, :password, :magic_link]
  @registrations [:open, :invite_only, :closed]
  @tenancies [:none, :organizations]
  @deployments [:render, :fly, :none]
  @default_session_absolute_minutes 30 * 24 * 60
  @default_session_idle_minutes 12 * 60

  @spec recipes() :: [atom()]
  def recipes, do: @recipes

  @spec auth_methods() :: [atom()]
  def auth_methods, do: @auth_methods

  @spec registrations() :: [atom()]
  def registrations, do: @registrations

  @spec tenancies() :: [atom()]
  def tenancies, do: @tenancies

  @spec deployments() :: [atom()]
  def deployments, do: @deployments

  @spec defaults(atom()) :: map()
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

  @spec wizard_defaults(String.t()) :: map()
  def wizard_defaults("internal"),
    do: %{auth: "google", registration: "invite-only", tenancy: "none", hosted: true}

  def wizard_defaults("saas"),
    do: %{auth: "google,password", registration: "open", tenancy: "organizations", hosted: false}

  def wizard_defaults("personal"),
    do: %{auth: "password,magic-link", registration: "open", tenancy: "none", hosted: false}

  def wizard_defaults("custom"),
    do: %{auth: "none", registration: "closed", tenancy: "none", hosted: false}

  def wizard_defaults(other),
    do:
      Mix.raise(
        "recipe must be one of #{Enum.map_join(@recipes, ", ", &Atom.to_string/1)}; got #{inspect(other)}"
      )

  @spec auth(term()) :: {:ok, [atom()]} | {:error, String.t()}
  def auth("none"), do: {:ok, []}
  def auth(:none), do: {:ok, []}

  def auth(value) when is_binary(value) do
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

  @spec enum(term(), [atom()], String.t()) :: {:ok, atom()} | {:error, String.t()}
  def enum(nil, _allowed, name), do: {:error, "--#{dashed(name)} is required"}

  def enum(value, allowed, name) when is_binary(value) do
    normalized = String.replace(value, "-", "_")

    case Enum.find(allowed, &(Atom.to_string(&1) == normalized)) do
      nil -> {:error, "#{name} must be one of #{Enum.map_join(allowed, ", ", &dashed/1)}"}
      match -> {:ok, match}
    end
  end

  @spec validate_combination([atom()], atom(), atom(), boolean()) :: :ok | {:error, String.t()}
  def validate_combination([], _registration, :organizations, _hosted),
    do: {:error, "no-auth applications do not support organization tenancy"}

  def validate_combination([], registration, _tenancy, _hosted) when registration != :closed,
    do: {:error, "no-auth applications require --registration closed"}

  def validate_combination(auth, _registration, _tenancy, true) do
    if :google in auth do
      :ok
    else
      {:error, "--google-hosted-domain requires google authentication"}
    end
  end

  def validate_combination(_auth, _registration, _tenancy, _hosted), do: :ok

  @spec dashed(atom() | String.t()) :: String.t()
  def dashed(value) when is_atom(value), do: value |> Atom.to_string() |> dashed()
  def dashed(value) when is_binary(value), do: String.replace(value, "_", "-")
end
