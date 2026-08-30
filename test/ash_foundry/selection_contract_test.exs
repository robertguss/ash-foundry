defmodule AshFoundry.SelectionContractTest do
  use ExUnit.Case, async: true

  alias AshFoundry.Selection

  setup_all do
    Code.require_file("installer/lib/ash_foundry_new/selection.ex")
    :ok
  end

  test "archive and package selection tables stay in lockstep" do
    for recipe <- Selection.recipes() do
      assert Selection.defaults(recipe) == AshFoundryNew.Selection.defaults(recipe)
    end

    assert Selection.recipes() == AshFoundryNew.Selection.recipes()
    assert Selection.auth_methods() == AshFoundryNew.Selection.auth_methods()
    assert Selection.registrations() == AshFoundryNew.Selection.registrations()
    assert Selection.tenancies() == AshFoundryNew.Selection.tenancies()
    assert Selection.deployments() == AshFoundryNew.Selection.deployments()
  end

  test "organization creation is compiled from recipe plus tenancy" do
    assert Selection.organization_creation(:saas, :organizations) == :open
    assert Selection.organization_creation(:internal, :organizations) == :system_admin
    assert Selection.organization_creation(:custom, :organizations) == :system_admin
    assert Selection.organization_creation(:saas, :none) == :none
  end
end
