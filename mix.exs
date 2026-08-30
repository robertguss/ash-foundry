defmodule AshFoundry.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/robertguss/ash-foundry"

  def project do
    [
      app: :ash_foundry,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Production-oriented Ash, Phoenix, Inertia, and React application generator",
      package: package(),
      source_url: @source_url,
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [extra_applications: [:eex, :logger]]
  end

  defp deps do
    [
      {:igniter, "== 0.8.3", optional: true},
      {:credo, "== 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "== 1.4.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "== 2.1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv/templates mix.exs README.md LICENSE)
    ]
  end
end
