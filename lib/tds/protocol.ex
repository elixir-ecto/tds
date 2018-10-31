defmodule Tds.Protocol do
  @moduledoc """
  Implements DBConnection behaviour for TDS protocol
  """
  import Tds.BinaryUtils
  import Tds.Messages
  import Tds.Utils

  alias Tds.Protocol
  alias Tds.Parameter
  alias Tds.Query
  import Bitwise

  require Logger

  @behaviour DBConnection

  # @packet_status_NORMAL 0x0 # more messaes
  # end of message
  @packet_status_EOM 0x1

  @timeout 5000
  @max_packet 4 * 1024
  @sock_opts [packet: :raw, mode: :binary, active: false, recbuf: 4096]
  @trans_levels [
    :read_uncommited,
    :read_commited,
    :repeatable_read,
    :snapshot,
    :serializable
  ]

  @type t :: %Protocol{
          sock: any,
          usock: any,
          itcp: integer(),
          opts: Keyword.t(),
          state: :ready,
          tail: binary(),
          pak_header: binary(),
          pak_data: binary(),
          result: list() | nil,
          query: list() | nil,
          transaction_status: :idle | :transaction | :error,
          env: map()
        }

  defstruct sock: nil,
            usock: nil,
            itcp: nil,
            opts: nil,
            state: :ready,
            # only has non-empty value when waiting for more data
            tail: "",
            # current tds packet header
            pak_header: "",
            # current tds message holding previous tds packets
            pak_data: "",
            result: nil,
            query: nil,
            transaction_status: :idle,
            env: %{trans: <<0x00>>, savepoint: 0}

  @impl DBConnection
  @spec connect(opts :: Keyword.t()) ::
          {:ok, state :: Protocol.t()} | {:error, Exception.t()}
  def connect(opts) do
    opts =
      opts
      |> Keyword.put_new(
        :username,
        System.get_env("MSSQLUSER") || System.get_env("USER")
      )
      |> Keyword.put_new(:password, System.get_env("MSSQLPASSWORD"))
      |> Keyword.put_new(:instance, System.get_env("MSSQLINSTANCE"))
      |> Keyword.put_new(:hostname, System.get_env("MSSQLHOST") || "localhost")
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    s = %__MODULE__{}

    case opts[:instance] do
      nil ->
        connect(opts, s)

      _instance ->
        case instance(opts, s) do
          {:ok, s} -> connect(opts, s)
          err -> {:error, err}
        end
    end
  end

  @impl DBConnection
  @spec disconnect(err :: Exception.t(), state :: Protocol.t()) :: :ok
  def disconnect(_err, %{sock: {mod, sock}} = s) do
    # If socket is active we flush any socket messages so the next
    # socket does not get the messages.
    _ = flush(s)
    mod.close(sock)
  end

  @impl DBConnection
  @spec ping(Protocol.t()) ::
          {:ok, Protocol.t()} | {:disconnect, Exception.t(), Protocol.t()}
  def ping(state) do
    case send_query(~s{SELECT 'pong' as [msg]}, state) do
      {:ok, _, s} ->
        {:ok, s}

      {:disconnect, :closed, s} ->
        {:disconnect, %Tds.Error{message: "Connection closed."}, s}

      {:error, err, s} ->
        err =
          if Exception.exception?(err) do
            err
          else
            Tds.Error.exception(inspect(err))
          end

        {:disconnect, err, s}

      any ->
        {:disconnect, Tds.Error.exception(inspect(any)), state}
    end
  end

  @impl DBConnection
  @spec checkout(state :: Protocol.t()) ::
          {:ok, new_state :: any}
          | {:disconnect, Exception.t(), new_state :: any}
  def checkout(%{sock: {_mod, sock}} = s) do
    case :inet.setopts(sock, active: false) do
      :ok -> {:ok, s}
      {:error, posix} -> {:disconnect, Tds.Error.exception(posix), s}
    end
  end

  @impl DBConnection
  @spec checkin(state :: any) ::
          {:ok, new_state :: any}
          | {:disconnect, Exception.t(), new_state :: any}
  def checkin(%{sock: {_mod, sock}} = s) do
    case :inet.setopts(sock, active: :once) do
      :ok -> {:ok, s}
      {:error, posix} -> {:disconnect, Tds.Error.exception(posix), s}
    end
  end

  @impl DBConnection
  @spec handle_execute(
          Tds.Query.t(),
          DBConnection.params(),
          opts :: Keyword.t(),
          state :: Protocol.t()
        ) ::
          {:ok, Tds.Query.t(), Tds.Result.t(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_execute(
        %Query{handle: handle, statement: statement} = query,
        params,
        opts,
        %{sock: _sock} = s
      ) do
    params = opts[:parameters] || params

    try do
      if params != [] do
        send_param_query(query, params, s)
      else
        send_query(statement, s)
      end
    rescue
      exception ->
        {:error, exception, s}
    else
      {:ok, result, state} ->
        {:ok, query, result, state}

      other ->
        other
    after
      unless is_nil(handle) do
        handle_close(query, opts, s)
      end
    end
  end

  @impl DBConnection
  @spec handle_prepare(
          Tds.Query.t(),
          opts :: Keyword.t(),
          state :: Protocol.t()
        ) ::
          {:ok, Tds.Query.t(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_prepare(%{statement: statement} = query, opts, %{sock: _sock} = s) do
    case Keyword.get(opts, :execution_mode, :prepare_execute) do
      :prepare_execute ->
        params =
          opts[:parameters]
          |> Parameter.prepared_params()

        send_prepare(statement, params, s)

      :executesql ->
        {:ok, query, %{s | state: :ready}}

      execution_mode ->
        message =
          "Unknown execution mode #{inspect(execution_mode)}, please check your config." <>
            "Supported modes are :prepare_execute and :executesql"

        {:error, %Tds.Error{message: message}, s}
    end
  end

  @impl DBConnection
  @spec handle_close(Query.t(), opts :: Keyword.t(), state :: Protocol.t()) ::
          {:ok, Tds.Result.t(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_close(query, opts, %{sock: _sock} = s) do
    params = opts[:parameters]

    send_close(query, params, s)
  end

  @impl DBConnection
  @spec handle_begin(opts :: Keyword.t(), state :: Protocol.t()) ::
          {:ok, Tds.Result.t(), new_state :: Protocol.t()}
          | {DBConnection.status(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Prototcol.t()}
  def handle_begin(opts, %{sock: _, env: env, transaction_status: status} = s) do
    case Keyword.get(opts, :mode, :transaction) do
      :transaction when status in [:idle] ->
        send_transaction("TM_BEGIN_XACT", nil, %{
          s
          | transaction_status: :transaction
        })

      :savepoint when status in [:transaction] ->
        savepoint = env.savepoint + 1
        env = %{env | savepoint: savepoint}
        s = %{s | env: env}
        send_transaction("TM_SAVE_XACT", savepoint, s)

      mode when mode in [:transaction, :savepoint] ->
        {status, s}
    end
  end

  @impl DBConnection
  @spec handle_commit(opts :: Keyword.t(), state :: any) ::
          {:ok, Tds.Result.t(), new_state :: Protocol.t()}
          | {DBConnection.status(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_commit(opts, %{transaction_status: status, env: env} = s) do
    case Keyword.get(opts, :mode, :transaction) do
      :transaction when status == :transaction ->
        send_transaction("TM_COMMIT_XACT", nil, %{s | transaction_status: :idle})

      :savepoint when status == :transaction ->
        send_transaction("TM_SAVE_XACT", env.savepoint, s)

      mode when mode in [:transaction, :savepoint] ->
        {status, s}
    end
  end

  @impl DBConnection
  @spec handle_rollback(opts :: Keyword.t(), state :: any) ::
          {:ok, Tds.Result.t(), new_state :: Protocol.t()}
          | {:idle, new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_rollback(opts, %{env: env, transaction_status: status} = s) do
    case Keyword.get(opts, :mode, :transaction) do
      :transaction when status == :transaction ->
        env = %{env | savepoint: 0}
        s = %{s | transaction_status: :idle, env: env}
        send_transaction("TM_ROLLBACK_XACT", 0, s)

      :savepoint when status == :transaction ->
        s = %{s | transaction_status: :error}
        send_transaction("TM_ROLLBACK_XACT", env.savepoint, s)

      mode when mode in [:transaction, :savepoint] ->
        {status, s}
    end
  end

  @impl DBConnection
  @spec handle_status(Keyword.t(), Protocol.t()) ::
          {:idle | :transaction | :error, Protocol.t()}
          | {:disconnect, Exception.t(), Protocol.t()}
  def handle_status(_, %Protocol{transaction_status: status} = state) do
    {status, state}
  end

  @impl DBConnection
  @spec handle_fetch(
          Query.t(),
          cursor :: any(),
          opts :: Keyword.t(),
          state :: Protocol.t()
        ) ::
          {:cont | :halt, Tds.Result.t(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_fetch(_query, _cursor, _opts, state) do
    {:error, Tds.Error.exception("Cursor is not supported by TDS"), state}
  end

  @impl DBConnection
  @spec handle_deallocate(
          query :: Query.t(),
          cursor :: any,
          opts :: Keyword.t(),
          state :: Protocol.t()
        ) ::
          {:ok, Tds.Result.t(), new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_deallocate(_query, _cursor, _opts, state) do
    {:error, Tds.Error.exception("Cursor operations are not supported in TDS"),
     state}
  end

  @impl DBConnection
  @spec handle_declare(
          Query.t(),
          params :: any,
          opts :: Keyword.t(),
          state :: Protocol.t()
        ) ::
          {:ok, Query.t(), cursor :: any, new_state :: Protocol.t()}
          | {:error | :disconnect, Exception.t(), new_state :: Protocol.t()}
  def handle_declare(_query, _params, _opts, state) do
    {:error, Tds.Error.exception("Cursor operations are not supported in TDS"),
     state}
  end

  # CONNECTION

  defp instance(opts, s) do
    host = Keyword.fetch!(opts, :hostname)
    host = if is_binary(host), do: String.to_charlist(host), else: host

    case :gen_udp.open(0, [:binary, {:active, false}, {:reuseaddr, true}]) do
      {:ok, sock} ->
        :gen_udp.send(sock, host, 1434, <<3>>)
        {:ok, msg} = :gen_udp.recv(sock, 0)
        parse_udp(msg, %{s | opts: opts, usock: sock})

      {:error, error} ->
        error(%Tds.Error{message: "udp connect: #{error}"}, s)
    end
  end

  defp connect(opts, s) do
    host = Keyword.fetch!(opts, :hostname)
    host = if is_binary(host), do: String.to_charlist(host), else: host
    port = s.itcp || opts[:port] || System.get_env("MSSQLPORT") || 1433
    {port, _} = if is_binary(port), do: Integer.parse(port), else: {port, nil}
    timeout = opts[:timeout] || @timeout
    sock_opts = @sock_opts ++ (opts[:socket_options] || [])

    s = %{s | opts: opts}

    case :gen_tcp.connect(host, port, sock_opts, timeout) do
      {:ok, sock} ->
        {:ok, [sndbuf: sndbuf, recbuf: recbuf, buffer: buffer]} =
          :inet.getopts(sock, [:sndbuf, :recbuf, :buffer])

        buffer =
          buffer
          |> max(sndbuf)
          |> max(recbuf)

        :ok = :inet.setopts(sock, buffer: buffer)

        case login(%{s | sock: {:gen_tcp, sock}}) do
          {:error, error, _state} ->
            :gen_tcp.close(sock)
            {:error, error}

          r ->
            r
        end

      {:error, error} ->
        error(%Tds.Error{message: "tcp connect: #{error}"}, s)
    end
  end

  defp parse_udp(
         {_, 1434, <<_head::binary-3, data::binary>>},
         %{opts: opts, usock: sock} = s
       ) do
    :gen_udp.close(sock)

    server =
      data
      |> String.split(";;")
      |> Enum.slice(0..-2)
      |> Enum.reduce([], fn str, acc ->
        server =
          str
          |> String.split(";")
          |> Enum.chunk(2)
          |> Enum.reduce([], fn [k, v], acc ->
            k =
              k
              |> String.downcase()
              |> String.to_atom()

            Keyword.put_new(acc, k, v)
          end)

        [server | acc]
      end)
      |> Enum.find(fn s ->
        String.downcase(s[:instancename]) == String.downcase(opts[:instance])
      end)

    case server do
      nil ->
        error(%Tds.Error{message: "Instance #{opts[:instance]} not found"}, s)

      serv ->
        {port, _} = Integer.parse(serv[:tcp])
        {:ok, %{s | opts: opts, itcp: port}}
    end
  end

  def handle_info({:udp_error, _, :econnreset}, s) do
    msg =
      "Tds encountered an error while connecting to the Sql Server " <>
        "Browser: econnreset"

    {:stop, Tds.Error.exception(msg), s}
  end

  def handle_info(
        {:tcp, _, _data},
        %{sock: {mod, sock}, opts: opts, state: :prelogin} = s
      ) do
    case mod do
      :gen_tcp -> :inet.setopts(sock, active: false)
      :ssl -> :ssl.setopts(sock, active: false)
    end

    login(%{s | opts: opts, sock: {mod, sock}})
  end

  def handle_info({tag, _}, s) when tag in [:tcp_closed, :ssl_closed] do
    {:stop, Tds.Error.exception("tcp closed"), s}
  end

  def handle_info({tag, _, reason}, s) when tag in [:tcp_error, :ssl_error] do
    {:stop, Tds.Error.exception("tcp error: #{reason}"), s}
  end

  def handle_info(msg, s) do
    Logger.debug(fn -> "Unhandled info: #{inspect(msg)}" end)

    {:ok, s}
  end

  # no data to process
  defp new_data(<<_data::0>>, s) do
    {:ok, s}
  end

  # DONE_ATTN The DONE message is a server acknowledgement of a client ATTENTION
  # message.
  defp new_data(
         <<0xFD, 0x20, _cur_cmd::binary(2), 0::size(8)-unit(8), _tail::binary>>,
         %{state: :attn} = s
       ) do
    s = %{s | pak_header: "", pak_data: "", tail: ""}
    message(:attn, :attn, s)
  end

  # shift 8 bytes while in attention state, Protocol updates state
  defp new_data(<<_b::size(1)-unit(8), tail::binary>>, %{state: :attn} = s) do
    new_data(tail, s)
  end

  # no packet header yet
  defp new_data(<<data::binary>>, %{pak_header: ""} = s) do
    if byte_size(data) >= 8 do
      # assume incoming data starts with packet header, if it's long enough
      # Logger.debug "S: #{inspect s}"
      <<pak_header::binary(8), tail::binary>> = data
      new_data(tail, %{s | pak_header: pak_header})
    else
      # have no packet header yet, wait for more data
      {:ok, %{s | tail: data}}
    end
  end

  defp new_data(
         <<data::binary>>,
         %{state: state, pak_header: pak_header, pak_data: pak_data} = s
       ) do
    <<type::int8, status::int8, size::int16, _head_rem::int32>> = pak_header
    # size includes packet header
    size = size - 8

    case data do
      <<package::binary(size), tail::binary>> ->
        # satisfied size specified in packet header
        case status &&& @packet_status_EOM do
          1 ->
            # status 1 means last packet of message
            # TODO Messages.parse does not use pak_header

            # :binpp.pprint(pak_header <> pak_data)

            msg = parse(state, type, pak_header, pak_data <> package)

            case message(state, msg, s) do
              {:ok, s} ->
                # message processed, reset header and msg buffer, then process
                # tail
                new_data(tail, %{s | pak_header: "", pak_data: ""})

              {:ok, _result, s} ->
                # send_query returns a result
                new_data(tail, %{s | pak_header: "", pak_data: ""})

              {:error, _, _} = err ->
                err
            end

          _ ->
            # not the last packet of message, more packets coming with new
            # packet header
            new_data(tail, %{s | pak_header: "", pak_data: pak_data <> package})
        end

      data ->
        # size specified in packet header still unsatisfied, wait for more data
        {:ok, %{s | tail: data, pak_header: pak_header}}
    end
  end

  defp flush(%{sock: sock} = s) do
    receive do
      {:tcp, ^sock, data} ->
        _ = new_data(data, s)
        {:ok, s}

      {:tcp_closed, ^sock} ->
        {:disconnect, %Tds.Error{message: "tcp closed"}, s}

      {:tcp_error, ^sock, reason} ->
        {:disconnect, %Tds.Error{message: "tcp error: #{reason}"}, s}
    after
      0 ->
        # There might not be any socket messages.
        {:ok, s}
    end
  end

  # PROTOCOL

  def prelogin(%{opts: opts} = s) do
    msg = msg_prelogin(params: opts)

    case msg_send(msg, s) do
      {:ok, s} ->
        {:noreply, %{s | state: :prelogin}}

      {:error, reason, s} ->
        error(%Tds.Error{message: "tcp send: #{reason}"}, s)

      any ->
        any
    end
  end

  def login(%{opts: opts} = s) do
    msg = msg_login(params: opts)

    case login_send(msg, s) do
      {:ok, s} ->
        {:ok, %{s | state: :executing}}

      err ->
        err
    end
  end

  def send_query(statement, s) do
    msg = msg_sql(query: statement)

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}

      {:error, err, %{transaction_status: :transaction} = s} ->
        {:error, err, %{s | transaction_status: :error}}

      err ->
        err
    end
  end

  def send_prepare(statement, params, s) do
    params = [
      %Tds.Parameter{
        name: "@handle",
        type: :integer,
        direction: :output,
        value: nil
      },
      %Tds.Parameter{name: "@params", type: :string, value: params},
      %Tds.Parameter{name: "@stmt", type: :string, value: statement}
    ]

    msg = msg_rpc(proc: :sp_prepare, query: statement, params: params)

    case msg_send(msg, s) do
      {:ok, %{query: query} = s} ->
        {:ok, %{query | statement: statement}, %{s | state: :ready}}

      {:error, err, %{transaction_status: :transaction} = s} ->
        {:error, err, %{s | transaction_status: :error}}

      err ->
        err
    end
  end

  def send_transaction(command, name, s) do
    msg = msg_transmgr(command: command, name: name)

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}

      err ->
        err
    end
  end

  def send_param_query(
        %Query{handle: handle, statement: statement} = _,
        params,
        s
      ) do
    msg =
      case handle do
        nil ->
          p = [
            %Parameter{
              name: "@statement",
              type: :string,
              direction: :input,
              value: statement
            },
            %Parameter{
              name: "@params",
              type: :string,
              direction: :input,
              value: Parameter.prepared_params(params)
            }
            | Parameter.prepare_params(params)
          ]

          msg_rpc(proc: :sp_executesql, params: p)

        handle ->
          p = [
            %Parameter{
              name: "@handle",
              type: :integer,
              direction: :input,
              value: handle
            }
            | Parameter.prepare_params(params)
          ]

          msg_rpc(proc: :sp_execute, params: p)
      end

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}

      {:error, err, %{transaction_status: :transaction} = s} ->
        {:error, err, %{s | transaction_status: :error}}

      err ->
        err
    end
  end

  def send_close(%Query{handle: handle} = _query, _params, s) do
    params = [
      %Tds.Parameter{
        name: "@handle",
        type: :integer,
        direction: :input,
        value: handle
      }
    ]

    msg = msg_rpc(proc: :sp_unprepare, params: params)

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}

      {:error, err, %{transaction_status: :transaction} = s} ->
        {:error, err, %{s | transaction_status: :error}}

      err ->
        err
    end
  end

  # def send_proc(proc, params, s) do
  #  msg = msg_rpc(proc: proc, params: params)
  #  case send_to_result(msg, s) do
  #    {:ok, s} ->
  #      {:ok, %{s | statement: nil, state: :executing}}
  #    err ->
  #      err
  #  end
  # end

  # def send_attn(s) do
  #  msg = msg_attn()
  #  simple_send(msg, s)

  #  {:ok, %{s | statement: nil, state: :attn}}
  # end

  ## SERVER Packet Responses

  # def message(:prelogin, _state) do
  # end

  def message(
        :login,
        msg_login_ack(redirect: true, tokens: tokens),
        %{opts: opts} = s
      ) do
    # we got an ENVCHANGE:redirection token, we need to disconnect and start over with new server
    disconnect(Tds.Error.exception(:redirected), s)
    %{hostname: host, port: port} = tokens[:env_redirect]

    new_opts =
      opts
      |> Keyword.put(:hostname, host)
      |> Keyword.put(:port, port)

    connect(new_opts)
  end

  def message(:login, msg_login_ack(), %{opts: opts} = s) do
    state = %{s | opts: clean_opts(opts)}

    opts
    |> conn_opts()
    |> IO.iodata_to_binary()
    |> send_query(state)
  end

  ## executing

  def message(
        :executing,
        msg_sql_result(columns: columns, rows: rows, done: done),
        %{} = s
      ) do
    columns =
      if columns != nil do
        columns
        |> Enum.reduce([], fn col, acc -> [col[:name] | acc] end)
        |> Enum.reverse()
      else
        columns
      end

    num_rows = done.rows

    # rows are correctly orrdered when they were parsed, so below is not needed
    # anymore
    # rows =
    # if rows != nil, do:  Enum.reverse(rows), else: rows

    rows = if num_rows == 0 && rows == nil, do: [], else: rows

    result = %Tds.Result{columns: columns, rows: rows, num_rows: num_rows}

    {:ok, %{s | state: :executing, result: result}}
  end

  def message(:executing, msg_trans(trans: trans), %{env: env} = s) do
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}

    {:ok,
     %{
       s
       | state: :ready,
         result: result,
         env: %{trans: trans, savepoint: env.savepoint}
     }}
  end

  def message(:executing, msg_prepared(params: params), %{} = s) do
    {"@handle", handle} = params

    result = %Tds.Result{columns: [], rows: [], num_rows: 0}
    query = %Tds.Query{handle: handle}

    {:ok, %{s | state: :ready, result: result, query: query}}
  end

  ## Error
  def message(_, msg_error(e: e), %{} = s) do
    error = %Tds.Error{mssql: e}
    {:error, error, %{s | pak_header: "", tail: ""}}
  end

  ## ATTN Ack
  def message(:attn, _, %{} = s) do
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}

    {:ok, %{s | statement: "", state: :ready, result: result}}
  end

  defp msg_send(msg, %{sock: {mod, sock}, env: env} = s) do
    :inet.setopts(sock, active: false)

    paks = encode_msg(msg, env)

    Enum.each(paks, fn pak ->
      mod.send(sock, pak)
    end)

    case msg_recv(<<>>, s) do
      {:disconnect, _ex, _s} = res ->
        res

      buffer ->
        new_data(buffer, %{s | state: :executing, pak_header: ""})
    end
  end

  defp msg_recv(buffer, %{sock: {mod, sock}} = s) do
    case mod.recv(sock, 8) do
      # there is more tds packages after this one
      {:ok,
       <<_type::int8, 0x00, length::int16, _spid::int16, _package::int8,
         _window::int8>> = header} ->
        (buffer <> header)
        |> package_recv(s, length - 8)
        |> msg_recv(s)

      # this heder belongs to last package
      {:ok,
       <<_type::int8, 0x01, length::int16, _spid::int16, _package::int8,
         _window::int8>> = header} ->
        package_recv(buffer <> header, s, length - 8)

      {:ok,
       <<_type::int8, stat::int8, _length::int16, _spid::int16, _package::int8,
         _window::int8>> = _header} ->
        # package_recv(buffer <> header, s, length - 8)
        msg = "Status #{inspect(stat)} of tds package is not yer supported!"
        {:disconnect, Tds.Error.exception(msg), s}

      {:error, :closed} ->
        ex = DBConnection.ConnectionError.exception("connection is closed")
        {:disconnect, ex, s}

      {:error, error} ->
        {:disconnect, Tds.Error.exception(error), s}
    end
  end

  defp package_recv(buffer, %{sock: {mod, sock}} = s, length) do
    case mod.recv(sock, min(length, @max_packet)) do
      # TODO: not much likely but since case `byte_size(data) > length` is not handled
      # it could be that here we have a bug
      # since more than one package could arrive for any reason
      # it should put to state tail and then return buffered package.
      # When respond to client parsed result, then continue receiving and processing tail
      {:ok, data} when byte_size(data) < length ->
        length = length - byte_size(data)
        package_recv(buffer <> data, s, length)

      {:ok, data} ->
        buffer <> data

      {:error, exception} ->
        {:disconnect, exception, s}
    end
  end

  defp login_send(msg, %{sock: {mod, sock}, env: env} = s) do
    paks = encode_msg(msg, env)

    Enum.each(paks, fn pak ->
      mod.send(sock, pak)
    end)

    case msg_recv(<<>>, s) do
      {:disconnect, ex, s} ->
        {:error, ex, s}

      buffer ->
        new_data(buffer, %{s | state: :login})
    end
  end

  defp clean_opts(opts) do
    Keyword.put(opts, :password, :REDACTED)
  end

  @spec conn_opts(Keyword.t()) :: list() | no_return
  defp conn_opts(opts) do
    [
      "SET ANSI_NULLS ON; ",
      "SET QUOTED_IDENTIFIER ON; ",
      "SET CURSOR_CLOSE_ON_COMMIT OFF; ",
      "SET ANSI_NULL_DFLT_ON ON; ",
      "SET ANSI_PADDING ON; ",
      "SET ANSI_WARNINGS ON; ",
      "SET CONCAT_NULL_YIELDS_NULL ON; ",
      "SET TEXTSIZE 2147483647; "
    ]
    |> append_opts(opts, :set_language)
    |> append_opts(opts, :set_datefirst)
    |> append_opts(opts, :set_dateformat)
    |> append_opts(opts, :set_deadlock_priority)
    |> append_opts(opts, :set_lock_timeout)
    |> append_opts(opts, :set_remote_proc_transactions)
    |> append_opts(opts, :set_implicit_transactions)
    |> append_opts(opts, :set_transaction_isolation_level)
    |> append_opts(opts, :set_allow_snapshot_isolation)
  end

  defp append_opts(conn, opts, :set_language) do
    case Keyword.get(opts, :set_language) do
      nil -> conn
      val -> conn ++ ["SET LANGUAGE #{val}; "]
    end
  end

  defp append_opts(conn, opts, :set_datefirst) do
    case Keyword.get(opts, :set_datefirst) do
      nil ->
        conn

      val when val in 1..7 ->
        conn ++ ["SET DATEFIRST #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_datefirst: #{inspect(val)} is out of bounds, valid range is 1..7"
        )
    end
  end

  defp append_opts(conn, opts, :set_dateformat) do
    case Keyword.get(opts, :set_dateformat) do
      nil ->
        conn

      val when val in [:mdy, :dmy, :ymd, :ydm, :myd, :dym] ->
        conn ++ ["SET DATEFORMAT #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_dateformat: #{inspect(val)} is an invalid value, " <>
            "valid values are [:mdy, :dmy, :ymd, :ydm, :myd, :dym]"
        )
    end
  end

  defp append_opts(conn, opts, :set_deadlock_priority) do
    case Keyword.get(opts, :set_deadlock_priority) do
      nil ->
        conn

      val when val in [:low, :high, :normal] ->
        conn ++ ["SET DEADLOCK_PRIORITY #{val}; "]

      nil ->
        conn

      val when val in -10..10 ->
        conn ++ ["SET DEADLOCK_PRIORITY #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_deadlock_priority: #{inspect(val)} is an invalid value, " <>
            "valid values are #{inspect([:low, :high, :normal | -10..10])}"
        )
    end
  end

  defp append_opts(conn, opts, :set_lock_timeout) do
    case Keyword.get(opts, :set_lock_timeout) do
      nil ->
        conn

      val when val > 0 ->
        conn ++ ["SET LOCK_TIMEOUT #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_lock_timeout: #{inspect(val)} is an invalid value, " <>
            "must be an positive integer."
        )
    end
  end

  defp append_opts(conn, opts, :set_remote_proc_transactions) do
    case Keyword.get(opts, :set_remote_proc_transactions) do
      nil ->
        conn

      val when val in [:on, :off] ->
        val = val |> Atom.to_string() |> String.upcase()
        conn ++ ["SET REMOTE_PROC_TRANSACTIONS #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_remote_proc_transactions: #{inspect(val)} is an invalid value, " <>
            "should be either :on, :off, nil"
        )
    end
  end

  defp append_opts(conn, opts, :set_implicit_transactions) do
    case Keyword.get(opts, :set_implicit_transactions) do
      nil ->
        conn ++ ["SET IMPLICIT_TRANSACTIONS OFF; "]

      val when val in [:on, :off] ->
        val = val |> Atom.to_string() |> String.upcase()
        conn ++ ["SET IMPLICIT_TRANSACTIONS #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_implicit_transactions: #{inspect(val)} is an invalid value, " <>
            "should be either :on, :off, nil"
        )
    end
  end

  defp append_opts(conn, opts, :set_transaction_isolation_level) do
    case Keyword.get(opts, :set_transaction_isolation_level) do
      nil ->
        conn

      val when val in @trans_levels ->
        t =
          val
          |> Atom.to_string()
          |> String.replace("_", " ")
          |> String.upcase()

        conn ++ ["SET TRANSACTION ISOLATION LEVEL #{t}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_transaction_isolation_level: #{inspect(val)} is an invalid value, " <>
            "should be one of #{inspect(@trans_levels)} or nil"
        )
    end
  end

  defp append_opts(conn, opts, :set_allow_snapshot_isolation) do
    database = Keyword.get(opts, :database)

    case Keyword.get(opts, :set_allow_snapshot_isolation) do
      nil ->
        conn

      val when val in [:on, :off] ->
        val = val |> Atom.to_string() |> String.upcase()

        conn ++
          ["ALTER DATABASE [#{database}] SET ALLOW_SNAPSHOT_ISOLATION #{val}; "]

      val ->
        raise(
          Tds.ConfigError,
          "set_allow_snapshot_isolation: #{inspect(val)} is an invalid value, " <>
            "should be either :on, :off, nil"
        )
    end
  end
end
