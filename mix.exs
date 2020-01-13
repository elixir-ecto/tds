defmodule Tds.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :tds,
      version: "2.1.0",
      elixir: "~> 1.0",
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      description: description(),
      package: package(),

      # Docs
      name: "Tds",
      source_url: "https://github.com/livehelpnow/tds",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      applications: [:logger, :db_connection, :decimal],
      env: [
        json_library: Jason
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:binpp, ">= 0.0.0", only: [:dev, :test]},
      {:decimal, "~> 1.6"},
      {:jason, "~> 1.0", optional: true},
      {:db_connection, "~> 2.0"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.18", only: :dev}
    ]
  end

  defp description do
    """
    Microsoft SQL Server client (Elixir implementation of the MS TDS protocol)
    """
  end

  defp package do
    [
      name: "tds",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Eric Witchin", "Milan Jaric"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/livehelpnow/tds"}
    ]
  end
end
