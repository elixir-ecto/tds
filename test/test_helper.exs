Application.ensure_all_started(:tzdata)

defmodule Tds.TestHelper do
  alias Tds.Connection

  require Logger

  def opts do
    [
      hostname: System.get_env("SQL_HOSTNAME") || "127.0.0.1",
      username: System.get_env("SQL_USERNAME") || "sa",
      password: System.get_env("SQL_PASSWORD") || "some!Password",
      database: "test",
      ssl: true,
      trace: false,
      set_allow_snapshot_isolation: :on,
      show_sensitive_data_on_connection_error: true
    ]
  end

  defmacro query(statement, params \\ [], opts \\ []) do
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

  defmacro query_multi(statement, params \\ [], opts \\ []) do
    quote do
      case Tds.query_multi(
             var!(context)[:pid],
             unquote(statement),
             unquote(params),
             unquote(opts)
           ) do
        {:ok, resultset} -> resultset
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

  defmacro drop_table(table) do
    quote bind_quoted: [table: table] do
      statement =
        "if exists(select * from sys.tables where [name] = '#{table}')" <>
          " drop table #{table}"

      Tds.query!(var!(context)[:pid], statement, [])
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
      # Set login timeout to 1 second
      "-l",
      "1",
      "-Q",
      ~s(#{sql}) | args
    ]

    System.cmd("sqlcmd", args, stderr_to_stdout: true)
  end

  def assert_sqlcmd! do
    if System.cmd("command", ["-v", "sqlcmd"]) |> elem(1) == 1 do
      IO.puts """
      sqlcmd not installed!

      To install it, follow these instructions:

      macOS:
        brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
        brew update
        brew install mssql-tools

      Ubuntu:
        curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
        curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
        sudo apt-get update
        sudo apt-get install mssql-tools unixodbc-dev
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
        source ~/.bashrc

      For other OS check:
        https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver15
      """


      System.halt(1)
    end
  end
end

opts = Tds.TestHelper.opts()
database = opts[:database]

Tds.TestHelper.assert_sqlcmd!()

case Tds.TestHelper.sqlcmd(opts, """
     IF EXISTS(SELECT * FROM sys.databases where name = '#{database}')
     BEGIN
       DROP DATABASE [#{database}];
     END;
     CREATE DATABASE [#{database}];
     """) do
  {"", 0} -> :ok
  _ -> raise RuntimeError, "Initalizing database failed. Is the database server running?"
end

{"Changed database context to 'test'." <> _, 0} =
  Tds.TestHelper.sqlcmd(opts, """
  USE [test];

  CREATE TABLE altering ([a] int)

  CREATE TABLE [composite1] ([a] int, [b] text);
  CREATE TABLE [composite2] ([a] int, [b] int, [c] int);
  CREATE TABLE [uniques] ([id] int NOT NULL, CONSTRAINT UIX_uniques_id UNIQUE([id]))
  """)

{"Changed database context to 'test'." <> _, 0} =
  Tds.TestHelper.sqlcmd(opts, """
  USE test
  GO
  CREATE SCHEMA test;
  """)

# :dbg.start()
# :dbg.tracer()
# :dbg.p(:all,:c)
# :dbg.tpl(Tds, :query, :x)

ExUnit.start()
ExUnit.configure(exclude: [:manual])
