defmodule AshFoundryNew.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/robertguss/ash-foundry"

  def project do
    [
      app: :ash_foundry_new,
      version: @version,
      elixir: "~> 1.18",
      deps: [],
      description: "Mix archive that creates new AshFoundry applications",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        files: ~w(lib mix.exs README.md LICENSE)
      ]
    ]
  end

  def application do
    [extra_applications: [:eex]]
  end
end
