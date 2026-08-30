defmodule AshFoundry.TemplateTest do
  use ExUnit.Case, async: true

  alias AshFoundry.{Plan, Template}

  @plans [
    Plan.build!("internal_app", recipe: "internal", deploy: "render"),
    Plan.build!("saas_app", recipe: "saas", deploy: "fly"),
    Plan.build!("personal_app", recipe: "personal", deploy: "none"),
    Plan.build!("operations_portal",
      recipe: "internal",
      auth: "password,magic-link",
      registration: "closed",
      tenancy: "organizations",
      deploy: "render"
    ),
    Plan.build!("public_tool",
      recipe: "custom",
      auth: "none",
      registration: "closed",
      tenancy: "none",
      deploy: "none"
    )
  ]

  test "every template resolves all conditionals and substitutions for every recipe" do
    templates = Path.wildcard("priv/templates/**/*.template", match_dot: true)

    for plan <- @plans, template <- templates do
      rendered = Template.render(template, plan)

      refute rendered =~ ~r/__IF_[A-Z_]+__/
      refute rendered =~ ~r/__END_[A-Z_]+__/
      refute rendered =~ "__APP__"
      refute rendered =~ "__MODULE__"
      refute rendered =~ "__WEB_MODULE__"
    end
  end

  test "rendered Elixir templates are syntactically valid for every recipe" do
    templates =
      Path.wildcard([
        "priv/templates/**/*.ex.template",
        "priv/templates/**/*.exs.template"
      ])

    for plan <- @plans, template <- templates do
      Code.string_to_quoted!(Template.render(template, plan), file: template)
    end
  end

  test "magic-link action matches whether registration is enabled" do
    template = "priv/templates/auth/lib/__app__/accounts/user.ex.template"

    closed =
      Plan.build!("closed_app",
        recipe: "internal",
        auth: "magic-link",
        registration: "closed",
        deploy: "none"
      )

    open = Plan.build!("open_app", recipe: "personal", deploy: "none")

    assert Template.render(template, closed) =~ "read :sign_in_with_magic_link do"
    refute Template.render(template, closed) =~ "create :sign_in_with_magic_link do"
    assert Template.render(template, open) =~ "create :sign_in_with_magic_link do"
    refute Template.render(template, open) =~ "read :sign_in_with_magic_link do"
  end

  test "security-sensitive templates compile the thermos fixes" do
    saas = Plan.build!("saas_app", recipe: "saas", deploy: "fly")
    internal = Plan.build!("internal_app", recipe: "internal", deploy: "none")

    rate_limit =
      Template.render(
        "priv/templates/auth/lib/__app___web/plugs/auth_rate_limit.ex.template",
        saas
      )

    assert rate_limit =~ "defp identifier_email(params)"
    refute rate_limit =~ "anonymous"

    runtime =
      Template.render("priv/templates/common/config/runtime.exs.template", saas)

    assert runtime =~ ~s[fetch_secret!.("SECRET_KEY_BASE", 32)]
    assert runtime =~ ~s[fetch_secret!.("TOKEN_SIGNING_SECRET", 32)]

    config = Template.render("priv/templates/common/config/config.exs.template", saas)
    assert config =~ "token_signing_secret:"

    user = Template.render("priv/templates/auth/lib/__app__/accounts/user.ex.template", saas)
    assert user =~ "require_confirmed_with :confirmed_at"
    assert user =~ "prevent_hijacking? false"
    assert user =~ "upsert_fields [:confirmed_at, :hashed_password]"

    router = Template.render("priv/templates/auth/lib/__app___web/router.ex.template", saas)
    assert router =~ ~s(get "/register")
    refute router =~ "__IF_OPEN_REGISTRATION__"

    membership =
      Template.render(
        "priv/templates/tenancy/lib/__app__/organizations/membership.ex.template",
        saas
      )

    assert membership =~ "upsert? true"
    assert membership =~ "upsert_identity :unique_organization_user"

    load_org =
      Template.render(
        "priv/templates/tenancy/lib/__app___web/plugs/load_organization.ex.template",
        saas
      )

    assert load_org =~ "system_admin"

    admin =
      Template.render(
        "priv/templates/auth/lib/__app___web/presenters/admin_presenter.ex.template",
        saas
      )

    assert admin =~ "Ash.Query.filter(query, organization_id =="

    organization =
      Template.render(
        "priv/templates/tenancy/lib/__app__/organizations/organization.ex.template",
        saas
      )

    assert organization =~ "authorize_if always()"
    refute organization =~ "__IF_SAAS__"

    internal_org =
      Template.render(
        "priv/templates/tenancy/lib/__app__/organizations/organization.ex.template",
        Plan.build!("ops", recipe: "internal", tenancy: "organizations", deploy: "none")
      )

    assert internal_org =~ "authorize_if actor_attribute_equals(:system_admin, true)"
    assert internal.organization_creation == :none

    auth =
      Template.render(
        "priv/templates/auth/lib/__app___web/controllers/auth_controller.ex.template",
        saas
      )

    assert auth =~ "confirmed_at: nil"
    assert auth =~ "AshAuthentication.Errors.UnconfirmedUser"
  end
end
