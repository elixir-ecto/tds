defmodule Tds.TestHelper do
  alias Tds.Connection

  require Logger

  defmacro query(statement, params, opts \\ []) do
    quote do
      case Tds.query(
             var!(context)[:pid],
             unquote(statement),
             unquote(params),
             unquote(opts)
           ) do
        {:ok, %Tds.Result{rows: nil}} -> :ok
        {:ok, %Tds.Result{rows: []}} -> :ok
        {:ok, %Tds.Result{rows: rows}} -> rows
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end

  defmacro query_multiset(statement, params, opts \\ []) do
    quote do
      case Tds.query(
             var!(context)[:pid],
             unquote(statement),
             unquote(params),
             unquote(opts)
             |> Keyword.put(:multiple_datasets, true)
           ) do
        {:ok, results} when is_list(results) ->
          Enum.map(results, fn %{rows: rows} -> rows end)
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end

  defmacro proc(proc, params, opts \\ []) do
    quote do
      case Connection.proc(
             var!(context)[:pid],
             unquote(proc),
             unquote(params),
             unquote(opts)
           ) do
        {:ok, %Tds.Result{rows: nil}} -> :ok
        {:ok, %Tds.Result{rows: []}} -> :ok
        {:ok, %Tds.Result{rows: rows}} -> rows
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end

  def sqlcmd(params, sql, args \\ []) do
    args = [
      "-U",
      params[:username],
      "-P",
      params[:password],
      "-S",
      params[:hostname],
      "-Q",
      ~s(#{sql}) | args
    ]

    System.cmd("sqlcmd", args)
  end
end

opts = Application.get_env(:tds, :opts)
database = opts[:database]
{"", 0} = Tds.TestHelper.sqlcmd(opts, """
IF NOT EXISTS(SELECT * FROM sys.databases where name = '#{database}')
BEGIN
  CREATE DATABASE [#{database}];
END;
""")

ExUnit.start()
ExUnit.configure(exclude: [:manual])
