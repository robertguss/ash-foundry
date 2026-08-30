defmodule AshFoundryNew.OptionsTest do
  use ExUnit.Case, async: true

  alias AshFoundryNew.Options

  test "expands recipe defaults for deterministic generation" do
    {app, options} = Options.parse!(~w(staff --recipe internal --deploy render --yes))

    assert app == "staff"
    assert options[:auth] == "google"
    assert options[:registration] == "invite-only"
    assert options[:tenancy] == "none"
    assert options[:google_hosted_domain]
  end

  test "preserves complete custom selections" do
    {_app, options} =
      Options.parse!(
        ~w(tool --recipe custom --auth none --registration closed --tenancy none --deploy none --yes)
      )

    assert Options.flags(options) == [
             "--recipe",
             "custom",
             "--auth",
             "none",
             "--registration",
             "closed",
             "--tenancy",
             "none",
             "--deploy",
             "none",
             "--no-google-hosted-domain"
           ]
  end

  test "wizard displays and normalizes each selection" do
    answers = Agent.start_link(fn -> ["saas", "", "", "", "fly", ""] end) |> elem(1)

    prompt = fn _message ->
      Agent.get_and_update(answers, fn [answer | rest] -> {answer <> "\n", rest} end)
    end

    {_app, options} = Options.parse!(["customer_portal"], prompt)
    assert options[:recipe] == "saas"
    assert options[:auth] == "google,password"
    assert options[:tenancy] == "organizations"
    assert options[:deploy] == "fly"
  end

  test "hands a custom base module to the installer without colliding with Igniter" do
    {_app, options} =
      Options.parse!(~w(portal --recipe internal --deploy none --module AcmePortal --yes))

    assert List.ends_with?(Options.flags(options), ["--ash-foundry-module", "AcmePortal"])
    assert Options.command("portal", options) =~ "--module AcmePortal"
  end
end
