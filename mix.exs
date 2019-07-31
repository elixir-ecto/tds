defmodule Tds.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :tds,
      version: "1.2.0",
      elixir: "~> 1.0",
      deps: deps(),
      compilers: [:rustler] ++ Mix.compilers(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      description: description(),
      package: package(),
      rustler_crates: [
        tds_encoding: [
          mode: (if Mix.env() == :prod, do: :release, else: :debug)
        ]
      ],

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
    [applications: [:logger, :db_connection, :decimal]]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:decimal, "~> 1.4"},
      {:db_connection, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.19", only: :dev},
      {:rustler, "~> 0.20.0"}
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
      files: ["lib", "mix.exs", "README*", "native"],
      maintainers: ["Eric Witchin", "Milan Jaric"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/livehelpnow/tds"}
    ]
  end
end
