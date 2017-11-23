defmodule Tds.TestHelper do
  require Logger
  defmacro query(statement, params, opts \\ []) do
    quote do
      case Tds.query(var!(context)[:pid], unquote(statement),
                                     unquote(params), unquote(opts)) do
        {:ok, %Tds.Result{rows: nil}} -> :ok
        {:ok, %Tds.Result{rows: []}} -> :ok
        {:ok, %Tds.Result{rows: rows}} -> rows
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end

  defmacro proc(proc, params, opts \\ []) do
    quote do
      case Tds.Connection.proc(var!(context)[:pid], unquote(proc),
                                     unquote(params), unquote(opts)) do
        {:ok, %Tds.Result{rows: nil}} -> :ok
        {:ok, %Tds.Result{rows: []}} -> :ok
        {:ok, %Tds.Result{rows: rows}} -> rows
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end

  def sqlcmd(params, sql, args \\ []) do
    args = [
      "-U", params[:username], 
      "-P", params[:password],
      "-S", params[:hostname],
      "-Q", ~s(#{sql}) | args]
    System.cmd "sqlcmd", args
  end
end


Application.get_env(:tds, :opts)
|> Tds.TestHelper.sqlcmd("IF NOT EXISTS(SELECT * FROM sys.databases where name = 'test') BEGIN CREATE DATABASE [test]; END;")

ExUnit.start()
