defmodule Tds.Mixfile do
  use Mix.Project

  @source_url "https://github.com/elixir-ecto/tds"
  @version "2.3.3"

  def project do
    [
      app: :tds,
      version: @version,
      elixir: "~> 1.11",
      name: "Tds",
      deps: deps(),
      docs: docs(),
      package: package(),
      xref: [exclude: [:ssl]],
      rustler_crates: [
        tds_encoding: [
          mode: if(Mix.env() == :prod, do: :release, else: :debug)
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :db_connection, :decimal, :ssl],
      env: [
        json_library: Jason
      ]
    ]
  end

  defp deps do
    [
      {:decimal, "~> 1.9 or ~> 2.0"},
      {:jason, "~> 1.0", optional: true},
      {:db_connection, "~> 2.0"},
      {:ex_doc, "~> 0.19", only: :docs},
      {:excoding, "~> 0.1", optional: true, only: :test},
      {:tzdata, "~> 1.0", optional: true, only: :test}
    ]
  end

  defp package do
    [
      description: "Microsoft SQL Server client (Elixir implementation of the MS TDS protocol)",
      name: "tds",
      files: ["lib", "mix.exs", "README*", "CHANGELOG*", "LICENSE*"],
      maintainers: ["Kevin Seidel"],
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
