defmodule Tds.Mixfile do
  use Mix.Project

  def project do
    [app: :tds,
     version: "0.5.4",
     elixir: "~> 1.0",
     deps: deps(),
     source_url: "https://github.com/livehelpnow/tds",
     description: description(),
     package: package()
     ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:decimal, "~> 1.1"},
    ]
  end

  defp description do
    """
    MSSQL / TDS Driver for Ecto.
    """
  end

  defp package do
    [maintainers: ["Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/livehelpnow/tds"}]
  end
end
