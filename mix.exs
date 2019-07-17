defmodule Mix.Tasks.Compile.Binutils do
  use Mix.Task.Compiler

  @libconv_version "1.9.1"

  def run(_args) do
    if match? {:win32, _}, :os.type do
      IO.puts("Compiling Windows NIFs")
      # download_iconv()
      # todo: download libiconv
      # {result, _error_code} = System.cmd("nmake", ["/F", "Makefile.win", "priv\\markdown.dll"], stderr_to_stdout: true)
      {result, _error_code} = System.cmd("make", ["priv/binaryutils.dll"], stderr_to_stdout: true)
      IO.binwrite result
    else
      File.mkdir_p("priv")
      {result, _error_code} = System.cmd("make", ["priv/binaryutils.so"], stderr_to_stdout: true)
      IO.binwrite result
    end
    :ok
  end

  defp download_iconv() do
    path = Path.join(File.cwd!, "priv/libconv")
    unless File.exists?(Path.join(path, "include/iconv.h")) do
      Application.ensure_all_started :inets
      {:ok, {_, _, content}} = :httpc.request(:get, {'http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.9.1.bin.woe32.zip', []}, [], [body_format: :binary])


      IO.puts("Extracking libconv ot #{path}")
      :zip.unzip(content, [{:cwd, path}])
    end
  end

  def clean() do
    File.rm_rf("priv/binaryutils.so")
    File.rm_rf("priv/binaryutils.dll")
  end
end

defmodule Tds.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :tds,
      version: "1.1.7",
      elixir: "~> 1.0",
      deps: deps(),
      compilers: [:binutils] ++ Mix.compilers(),
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
    [applications: [:logger, :db_connection, :decimal]]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:decimal, "~> 1.4"},
      {:db_connection, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.19", only: :dev}
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
