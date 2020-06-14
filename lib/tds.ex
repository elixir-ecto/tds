defmodule Tds do
  @moduledoc """
  Microsoft SQL Server driver for Elixir.

  Tds is partial implementation of the Micorosoft SQL Server
  [MS-TDS](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds)
  Tabular Data Stream Protocol.

  A Tds query is performed in separate server-side prepare and execute stages.
  At the moment query handle is not reused, but there is plan to cahce handles in
  near feature. It uses [RPC](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/619c43b6-9495-4a58-9e49-a4950db245b3)
  requests by default to `Sp_Prepare` (ProcId=11) and `Sp_Execute` (ProcId=12)
  query, but it is possible to configure driver to use only Sp_ExecuteSql.
  Please consult with [configuration](readme.html#configuration) how to do this.
  """
  alias Tds.Query

  @timeout 5000
  @execution_mode :prepare_execute

  @type start_option ::
          {:hostname, String.t()}
          | {:port, :inet.port_number()}
          | {:database, String.t()}
          | {:username, String.t()}
          | {:password, String.t()}
          | {:timeout, timeout}
          | {:connect_timeout, timeout}
          | DBConnection.start_option()

  @type isolation_level ::
          :read_uncommitted
          | :read_committed
          | :repeatable_read
          | :serializable
          | :snapshot
          | :no_change

  @type conn :: DBConnection.conn()

  @type resultset :: list(Tds.Result.t())

  @type option :: DBConnection.option()

  @type transaction_option ::
          {:mode, :transaction | :savepoint}
          | {:isolation_level, isolation_level()}
          | option()

  @type execute_option ::
          {:decode_mapper, (list -> term)}
          | {:resultset, boolean()}
          | option

  @spec start_link([start_option]) ::
          {:ok, conn} | {:error, Tds.Error.t() | term}
  def start_link(opts \\ []) do
    DBConnection.start_link(Tds.Protocol, default(opts))
  end

  @spec query(conn, iodata, list, [execute_option]) ::
          {:ok, Tds.Result.t()} | {:error, Exception.t()}
  def query(conn, statement, params, opts \\ []) do
    query = %Query{statement: statement}
    opts = Keyword.put_new(opts, :parameters, params)

    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      {:error, err} -> {:error, err}
    end
  end

  @spec query!(conn, iodata, list, [execute_option]) ::
          Tds.Result.t() | no_return()
  def query!(conn, statement, params, opts \\ []) do
    query = %Query{statement: statement}
    opts = Keyword.put_new(opts, :parameters, params)

    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, _query, result} -> result
      {:error, %{mssql: %{msg_text: msg}}} -> raise Tds.Error, msg
      {:error, err} -> raise err
    end
  end

  @doc """
  Executes statement that can contain multiple sql batches, result will contain
  all results that server yield for each batch.
  """
  @spec query_multi(conn(), iodata(), option(), [execute_option]) ::
          {:ok, resultset()}
          | {:error, Exception.t()}
  def query_multi(conn, statemnt, params, opts \\ []) do
    query = %Query{statement: statemnt}

    opts =
      opts
      |> Keyword.put_new(:parameters, params)
      |> Keyword.put_new(:resultset, true)

    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, _query, resultset} -> {:ok, resultset}
      {:error, err} -> {:error, err}
    end
  end

  @spec prepare(conn, iodata, [option]) ::
          {:ok, Tds.Query.t()} | {:error, Exception.t()}
  def prepare(conn, statement, opts \\ []) do
    query = %Query{statement: statement}

    case DBConnection.prepare(conn, query, opts) do
      {:ok, query} -> {:ok, query}
      {:error, err} -> {:error, err}
    end
  end

  @spec prepare!(conn, iodata, [option]) :: Tds.Query.t() | no_return()
  def prepare!(conn, statement, opts \\ []) do
    query = %Query{statement: statement}

    case DBConnection.prepare(conn, query, opts) do
      {:ok, query} -> query
      {:error, %{mssql: %{msg_text: msg}}} -> raise Tds.Error, msg
      {:error, err} -> raise err
    end
  end

  @spec execute(conn, Tds.Query.t(), list, [execute_option]) ::
          {:ok, Tds.Query.t(), Tds.Result.t()}
          | {:error, Tds.Error.t()}
  def execute(conn, query, params, opts \\ []) do
    case DBConnection.execute(conn, query, params, opts) do
      {:ok, q, result} -> {:ok, q, result}
      {:error, err} -> {:error, err}
    end
  end

  @spec execute!(conn, Tds.Query.t(), list, [execute_option]) ::
          Tds.Result.t()
  def execute!(conn, query, params, opts \\ []) do
    case DBConnection.execute(conn, query, params, opts) do
      {:ok, _q, result} -> result
      {:error, %{mssql: %{msg_text: msg}}} -> raise Tds.Error, msg
      {:error, err} -> raise err
    end
  end

  @spec close(conn, Tds.Query.t(), [option]) :: :ok | {:error, Exception.t()}
  def close(conn, query, opts \\ []) do
    case DBConnection.close(conn, query, opts) do
      {:ok, result} -> {:ok, result}
      {:error, err} -> {:error, err}
    end
  end

  @spec close!(conn, Tds.Query.t(), [option]) :: :ok
  def close!(conn, query, opts \\ []) do
    case DBConnection.close(conn, query, opts) do
      {:ok, result} -> result
      {:error, %{mssql: %{msg_text: msg}}} -> raise Tds.Error, msg
      {:error, err} -> raise err
    end
  end

  @spec transaction(conn, (DBConnection.t() -> result), [transaction_option()]) ::
          {:ok, result} | {:error, any}
        when result: var
  def transaction(conn, fun, opts \\ []) do
    DBConnection.transaction(conn, fun, opts)
  end

  @spec rollback(DBConnection.t(), reason :: any) :: no_return
  defdelegate rollback(conn, any), to: DBConnection

  @spec child_spec([start_option]) :: Supervisor.Spec.spec()
  def child_spec(opts) do
    DBConnection.child_spec(Tds.Protocol, default(opts))
  end

  defp default(opts) do
    opts
    |> Keyword.put_new(:idle_timeout, @timeout)
    |> Keyword.put_new(:execution_mode, @execution_mode)
  end

  @doc """
  Returns the configured JSON library.

  To customize the JSON library, include the following in your `config/config.exs`:

      config :tds, json_library: SomeJSONModule

  Defaults to `Jason`.
  """
  @spec json_library() :: module()
  def json_library() do
    Application.fetch_env!(:tds, :json_library)
  end

  @doc """
  Generates a version 4 (random) UUID in the MS uniqueidentifier binary format.
  """
  @spec generate_uuid :: <<_::128>>
  def generate_uuid(), do: Tds.Types.UUID.bingenerate()

  @doc """
  Decodes MS uniqueidentifier binary to its string representation
  """
  def decode_uuid(uuid), do: Tds.Types.UUID.load(uuid)

  @doc """
  Same as `decode_uuid/1` but raises `ArgumentError` if value is invalid
  """
  def decode_uuid!(uuid) do
    case Tds.Types.UUID.load(uuid) do
      {:ok, value} ->
        value

      :error ->
        raise ArgumentError, "Invalid uuid binary #{inspect(uuid)}"
    end
  end

  @doc """
  Encodes uuid string into MS uniqueidentifier binary
  """
  @spec encode_uuid(any) :: :error | {:ok, <<_::128>>}
  def encode_uuid(value), do: Tds.Types.UUID.dump(value)

  @doc """
  Same as `encode_uuid/1` but raises `ArgumentError` if value is invalid
  """
  @spec encode_uuid!(any) :: <<_::128>>
  def encode_uuid!(value), do: Tds.Types.UUID.dump!(value)
end
