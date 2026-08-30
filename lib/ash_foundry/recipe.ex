defmodule AshFoundry.Recipe do
  @moduledoc "Recipe defaults and normalized generation plans."

  alias AshFoundry.Plan

  @recipes [:internal, :saas, :personal, :custom]

  @doc "Returns all supported v1 recipe names."
  @spec all() :: [Plan.recipe()]
  def all, do: @recipes

  @doc "Returns the confirmed defaults for a recipe."
  @spec defaults(Plan.recipe()) :: map()
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
      session_absolute_minutes: 30 * 24 * 60,
      session_idle_minutes: 12 * 60
    }
  end

  def defaults(:personal) do
    %{
      auth: [:password, :magic_link],
      registration: :open,
      tenancy: :none,
      google_hosted_domain: false,
      session_absolute_minutes: 30 * 24 * 60,
      session_idle_minutes: 12 * 60
    }
  end

  def defaults(:custom), do: %{}
end
