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

  defmacro transaction(fun, opts \\ []) do
    quote do
      Tds.transaction(
        var!(context)[:pid],
        unquote(fun),
        unquote(opts)
      )
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
IF EXISTS(SELECT * FROM sys.databases where name = '#{database}')
BEGIN
  DROP DATABASE [#{database}];
END;
CREATE DATABASE [#{database}];
""")
{"Changed database context to 'test'.\n", 0} = Tds.TestHelper.sqlcmd(opts, """
USE [test];

CREATE TABLE altering ([a] int)

CREATE TABLE [composite1] ([a] int, [b] text);
CREATE TABLE [composite2] ([a] int, [b] int, [c] int);
CREATE TABLE [uniques] ([id] int NOT NULL, CONSTRAINT UIX_uniques_id UNIQUE([id]))
""")

{"Changed database context to 'test'.\n", 0} = Tds.TestHelper.sqlcmd opts, """
USE test
GO
CREATE SCHEMA test;
"""

# :dbg.tracer()
# :dbg.p(:all,:c)
# :dbg.tpl(Tds, :query, :x)


ExUnit.start()
ExUnit.configure(exclude: [:manual])
