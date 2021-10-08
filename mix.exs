defmodule Tds.Mixfile do
  @moduledoc false
  use Mix.Project

  @version "2.1.3"
  def project do
    [
      app: :tds,
      version: @version,
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
      xref: [exclude: [:ssl]],
      rustler_crates: [
        tds_encoding: [
          mode: if(Mix.env() == :prod, do: :release, else: :debug)
        ]
      ],

      # Docs
      name: "Tds",
      source_url: "https://github.com/livehelpnow/tds",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        source_ref: "v#{@version}",
        source_url: "https://github.com/livehelpnow/tds"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :db_connection, :decimal],
      env: [
        json_library: Jason
      ]
    ]
  end

  defp deps do
    [
      {:binpp, ">= 0.0.0", only: [:dev, :test]},
      {:decimal, "~> 1.6"},
      {:jason, "~> 1.0", optional: true},
      {:db_connection, "~> 2.0"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:tds_encoding, "~> 1.0", optional: true, only: :test},
      {:tzdata, "~> 1.0", optional: true, only: :test}
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
