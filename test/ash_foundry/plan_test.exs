defmodule AshFoundry.PlanTest do
  use ExUnit.Case, async: true

  alias AshFoundry.Plan

  test "normalizes confirmed recipe defaults" do
    assert {:ok, internal} = Plan.build("staff_portal", recipe: "internal", deploy: "render")
    assert internal.auth == [:google]
    assert internal.registration == :invite_only
    assert internal.tenancy == :none
    assert internal.google_hosted_domain
    assert internal.session_idle_minutes == 30

    assert {:ok, saas} = Plan.build("customer_app", recipe: "saas", deploy: "fly")
    assert saas.auth == [:google, :password]
    assert saas.registration == :open
    assert saas.tenancy == :organizations

    assert {:ok, personal} = Plan.build("journal", recipe: "personal", deploy: "none")
    assert personal.auth == [:password, :magic_link]
  end

  test "supports every critical override deterministically" do
    assert {:ok, plan} =
             Plan.build("private_app",
               ash_foundry_module: "OperationsPortal",
               recipe: "internal",
               auth: "password,magic-link",
               registration: "closed",
               tenancy: "organizations",
               deploy: "fly",
               google_hosted_domain: false
             )

    assert plan.auth == [:password, :magic_link]
    assert plan.module == "OperationsPortal"
    assert plan.registration == :closed
    assert plan.tenancy == :organizations
    assert plan.deploy == :fly
    refute plan.google_hosted_domain
  end

  test "requires explicit custom selections and a deployment decision" do
    assert {:error, message} = Plan.build("custom_app", recipe: "custom", deploy: "none")
    assert message =~ "custom recipe requires --auth"

    assert {:error, "--deploy is required"} = Plan.build("app", recipe: "personal")
  end

  test "supports a genuinely non-authenticated custom application" do
    assert {:ok, plan} =
             Plan.build("public_tool",
               recipe: "custom",
               auth: "none",
               registration: "closed",
               tenancy: "none",
               deploy: "none"
             )

    assert plan.auth == []
  end

  test "rejects contradictory and unsafe options" do
    assert {:error, message} =
             Plan.build("public_tool",
               recipe: "custom",
               auth: "none",
               registration: "open",
               tenancy: "none",
               deploy: "none"
             )

    assert message =~ "no-auth applications require"

    assert {:error, message} =
             Plan.build("public_tool",
               recipe: "custom",
               auth: "none",
               registration: "closed",
               tenancy: "organizations",
               deploy: "none"
             )

    assert message =~ "do not support organization tenancy"

    assert {:error, message} =
             Plan.build("public_tool",
               recipe: "personal",
               deploy: "none",
               google_hosted_domain: true
             )

    assert message =~ "requires google authentication"
  end

  test "provenance is complete and contains no runtime secrets" do
    plan = Plan.build!("portal", recipe: "internal", module: "CustomerPortal", deploy: "render")
    provenance = Plan.provenance(plan)

    assert provenance =~ "ash_foundry: \"0.1.0\""
    assert provenance =~ "module: \"CustomerPortal\""
    assert provenance =~ "recipe: :internal"
    refute provenance =~ "SECRET_KEY_BASE"
    refute provenance =~ "GOOGLE_CLIENT_SECRET"
  end
end
