defmodule ElixirTrpc.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_trpc,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:jason, "~> 1.4", optional: true}
    ]
  end
end
