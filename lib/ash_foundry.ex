defmodule AshFoundry do
  @moduledoc """
  Installs an application-owned AshFoundry architecture into a new Phoenix app.

  Use the `ash_foundry_new` archive for application creation. The package's
  `ash_foundry.install` task is public so recipes can be tested and composed by
  Igniter, but v1 intentionally does not support arbitrary existing projects.
  """

  @version "0.1.0"

  @doc "The AshFoundry package and provenance version."
  @spec version() :: String.t()
  def version, do: @version
end
