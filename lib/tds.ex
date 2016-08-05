defmodule Tds do

  alias Tds.Query

  require Logger

  @timeout 5000

  def start_link(opts \\ []) do
    DBConnection.start_link(Tds.Protocol, default(opts))
  end

  def query(pid, statement, params, opts \\ []) do
    Logger.debug "CALLED query/3"
    Logger.debug "QUERY: #{inspect statement}"
    Logger.debug "PARAMS: #{inspect params}"
    Logger.debug "OPTS: #{inspect opts}"

    query = %Query{statement: statement}
    opts = Keyword.put_new(opts, :parameters, params)

    case DBConnection.prepare_execute(pid, query, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      {:error, err} -> {:error, err}
    end
  end
  def query!(pid, statement, params, opts \\ []) do
    Logger.debug "CALLED query!/3"
    Logger.debug "QUERY: #{inspect statement}"
    Logger.debug "PARAMS: #{inspect params}"
    Logger.debug "OPTS: #{inspect opts}"

    query = %Query{statement: statement}
    opts = Keyword.put_new(opts, :parameters, params)

    case DBConnection.prepare_execute(pid, query, params, opts) do
      {:ok, _query, result} -> result
      {:error, err} -> raise err.mssql.msg_text
    end
  end

  def prepare(pid, statement, opts \\ []) do
    Logger.debug "CALLED prepare/2"
    Logger.debug "STATEMENT: #{inspect statement}"
    Logger.debug "OPTS: #{inspect opts}"

    query = %Query{statement: statement}

    case DBConnection.prepare(pid, query, opts) do
      {:ok, query} -> {:ok, query}
      {:error, err} -> {:error, err}
    end
  end
  def prepare!(pid, statement, opts \\ []) do
    Logger.debug "CALLED prepare!/2"
    Logger.debug "STATEMENT: #{inspect statement}"
    Logger.debug "OPTS: #{inspect opts}"

    query = %Query{statement: statement}

    case DBConnection.prepare(pid, query, opts) do
      {:ok, query} -> query
      {:error, err} -> raise err.mssql.msg_text
    end
  end

  def execute(pid, query, params, opts \\ []) do
    Logger.debug "CALLED execute/3"
    Logger.debug "QUERY: #{inspect query}"
    Logger.debug "OPTS: #{inspect opts}"

    case DBConnection.execute(pid, query, params, opts) do
      {:ok, result} -> {:ok, result}
      {:error, err} -> {:error, err}
    end
  end
  def execute!(pid, query, params, opts \\ []) do
    Logger.debug "CALLED execute!/3"
    Logger.debug "QUERY: #{inspect query}"
    Logger.debug "OPTS: #{inspect opts}"

    case DBConnection.execute(pid, query, params, opts) do
      {:ok, result} -> result
      {:error, err} -> err.mssql.msg_text
    end
  end

  def close(pid, query, opts \\ []) do
    Logger.debug "CALLED close/2"
    Logger.debug "QUERY: #{inspect query}"
    Logger.debug "OPTS: #{inspect opts}"

    case DBConnection.close(pid, query, opts) do
      {:ok, result} -> {:ok, result}
      {:error, err} -> {:error, err}
    end
  end
  def close!(pid, query, opts \\ []) do
    Logger.debug "CALLED close!/2"
    Logger.debug "QUERY: #{inspect query}"
    Logger.debug "OPTS: #{inspect opts}"

    case DBConnection.close(pid, query, opts) do
      {:ok, result} -> result
      {:error, err} -> err.mssql.msg_text
    end
  end

  def transaction(pid, fun, opts \\ []) do
    Logger.debug "CALLED transaction/2"
    Logger.debug "QUERY: #{inspect fun}"
    Logger.debug "OPTS: #{inspect opts}"

     case DBConnection.transaction(pid, fun, opts) do
       {:ok, result} -> result
       err -> err
     end
  end

  defdelegate rollback(conn, any), to: DBConnection

  def child_spec(opts) do
    DBConnection.child_spec(Tds.Protocol, default(opts))
  end

  defp default(opts) do
    opts
    |> Keyword.put_new(:idle_timeout, @timeout)
  end
end
