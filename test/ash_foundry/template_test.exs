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
end
