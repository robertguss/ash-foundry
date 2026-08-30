defmodule AshFoundry.GeneratorTest do
  use ExUnit.Case, async: true

  alias AshFoundry.{Generator, Plan}

  test "custom module paths preserve module-independent files" do
    plan =
      Plan.build!("custom_path",
        ash_foundry_module: "OperationsPortal",
        recipe: "internal",
        deploy: "render"
      )

    igniter =
      Igniter.Test.test_project(
        app_name: :custom_path,
        files: %{
          "assets/package.json" => ~s({"private": true}),
          "lib/custom_path/application.ex" =>
            "defmodule OperationsPortal.Application, do: use(Application)"
        }
      )
      |> Generator.generate(plan)

    assert Igniter.exists?(igniter, "mix.exs")
    assert Igniter.exists?(igniter, "assets/package.json")
    assert Igniter.exists?(igniter, "lib/operations_portal/application.ex")
    refute Igniter.exists?(igniter, "lib/custom_path/application.ex")
    refute "mix.exs" in igniter.rms
    refute "assets/package.json" in igniter.rms
  end

  test "disabled capabilities do not leave empty source files" do
    plan =
      Plan.build!("public_tool",
        recipe: "custom",
        auth: "none",
        registration: "closed",
        tenancy: "none",
        deploy: "none"
      )

    igniter =
      [app_name: :public_tool]
      |> Igniter.Test.test_project()
      |> Generator.generate(plan)

    refute Igniter.exists?(igniter, "lib/public_tool/accounts/user_identity.ex")
  end

  test "every selected template group exists on disk" do
    root =
      :ash_foundry
      |> :code.priv_dir()
      |> to_string()
      |> Path.join("templates")

    plans = [
      Plan.build!("internal_app", recipe: "internal", deploy: "render"),
      Plan.build!("saas_app", recipe: "saas", deploy: "fly"),
      Plan.build!("personal_app", recipe: "personal", deploy: "none"),
      Plan.build!("public_tool",
        recipe: "custom",
        auth: "none",
        registration: "closed",
        tenancy: "none",
        deploy: "none"
      )
    ]

    for plan <- plans, group <- Generator.template_groups(plan) do
      assert File.dir?(Path.join(root, group)), "missing template group #{group}"
    end

    refute "no_tenancy" in Enum.flat_map(plans, &Generator.template_groups/1)
  end
end
