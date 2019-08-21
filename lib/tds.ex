defmodule Tds do
  alias Tds.Query

  @timeout 5000
  @execution_mode :prepare_execute

  def start_link(opts \\ []) do
    DBConnection.start_link(Tds.Protocol, default(opts))
  end

  def query(pid, statement, params, opts \\ []) do
    query = %Query{statement: statement}
    opts = Keyword.put_new(opts, :parameters, params)

    case DBConnection.prepare_execute(pid, query, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      {:error, err} -> {:error, err}
    end
  end

  def query!(pid, statement, params, opts \\ []) do
    query = %Query{statement: statement}
    opts = Keyword.put_new(opts, :parameters, params)

    case DBConnection.prepare_execute(pid, query, params, opts) do
      {:ok, _query, result} -> result
      {:error, err} -> raise err
    end
  end

  def prepare(pid, statement, opts \\ []) do
    query = %Query{statement: statement}

    case DBConnection.prepare(pid, query, opts) do
      {:ok, query} -> {:ok, query}
      {:error, err} -> {:error, err}
    end
  end

  def prepare!(pid, statement, opts \\ []) do
    query = %Query{statement: statement}

    case DBConnection.prepare(pid, query, opts) do
      {:ok, query} -> query
      {:error, err} -> raise err.mssql.msg_text
    end
  end

  defdelegate execute(pid, query, params, opts \\ []), to: DBConnection

  def execute!(pid, query, params, opts \\ []) do
    case DBConnection.execute(pid, query, params, opts) do
      {:ok, result} -> result
      {:error, err} -> err.mssql.msg_text
    end
  end

  defdelegate close(pid, query, opts \\ []), to: DBConnection

  def close!(pid, query, opts \\ []) do
    case DBConnection.close(pid, query, opts) do
      {:ok, result} -> result
      {:error, err} -> err.mssql.msg_text
    end
  end

  defdelegate transaction(pid, fun, opts \\ []), to: DBConnection

  @spec rollback(DBConnection.t, reason :: any) :: no_return
  defdelegate rollback(conn, any), to: DBConnection

  def child_spec(opts) do
    DBConnection.child_spec(Tds.Protocol, default(opts))
  end

  defp default(opts) do
    opts
    |> Keyword.put_new(:idle_timeout, @timeout)
    |> Keyword.put_new(:execution_mode, @execution_mode)
  end
end
