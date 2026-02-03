defmodule Yuzu.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/robsonperassoli/yuzu"
  @description "TRPC-style RPC endpoints for Elixir with compile-time schema definitions"

  def project do
    [
      app: :yuzu,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Yuzu",
      description: @description,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:zoi, "~> 0.17"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: :yuzu,
      description: @description,
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/yuzu"
      },
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
