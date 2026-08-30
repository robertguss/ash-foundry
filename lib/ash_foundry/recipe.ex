defmodule AshFoundry.Recipe do
  @moduledoc "Recipe names and defaults. `AshFoundry.Selection` is the compiler."

  alias AshFoundry.{Plan, Selection}

  @doc "Returns all supported v1 recipe names."
  @spec all() :: [Plan.recipe()]
  def all, do: Selection.recipes()

  @doc "Returns the confirmed defaults for a recipe."
  @spec defaults(Plan.recipe()) :: map()
  def defaults(recipe), do: Selection.defaults(recipe)
end
