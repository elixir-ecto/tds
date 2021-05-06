defmodule Tds.Protocol do
  @moduledoc """
  Implements DBConnection behaviour for TDS protocol
  """
  import Tds.BinaryUtils
  import Tds.Messages
  import Tds.Utils

  alias Tds.Parameter
  alias Tds.Query

  require Logger

  @behaviour DBConnection

  @timeout 5000
  @sock_opts [packet: :raw, mode: :binary, active: false]
  @trans_levels [
    :read_uncommitted,
    :read_committed,
    :repeatable_read,
    :snapshot,
    :serializable
  ]

  @type sock :: {:gen_tcp | :ssl, pid}
  @type env :: %{
          trans: <<_::8>>,
          savepoint: non_neg_integer,
          collation: Tds.Protocol.Collation.t(),
          packetsize: integer
        }
  @type transaction :: nil | :started | :successful | :failed
  @type state ::
          :ready
          | :prelogin
          | :login
          | :prepare
          | :executing
  @type packet_data :: binary

  @type t :: %__MODULE__{
          sock: nil | sock,
          usock: nil | pid,
          itcp: term,
          opts: nil | Keyword.t(),
          state: state,
          result: nil | list(),
          query: nil | String.t(),
          transaction: transaction,
          env: env
        }

  defstruct sock: nil,
            usock: nil,
            itcp: nil,
            opts: nil,
            # Tells if connection is ready or executing command
            state: :ready,
            result: nil,
            query: nil,
            transaction: nil,
            env: %{
              trans: <<0x00>>,
              savepoint: 0,
              collation: %Tds.Protocol.Collation{},
              packetsize: 4096
            }

  @impl DBConnection
  @spec connect(opts :: Keyword.t()) ::
          {:ok, state :: t()} | {:error, Exception.t()}
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
  @spec disconnect(err :: Exception.t() | String.t(), state :: t()) ::
          :ok
  def disconnect(_err, %{sock: {mod, sock}} = s) do
    # If socket is active we flush any socket messages so the next
    # socket does not get the messages.
    _ = flush(s)
    mod.close(sock)
  end

  @impl DBConnection
  @spec ping(t) :: {:ok, t} | {:disconnect, Exception.t(), t}
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
  @spec checkout(state :: t) ::
          {:ok, new_state :: any}
          | {:disconnect, Exception.t(), new_state :: t}
  def checkout(%{transaction: :started} = s) do
    err = %Tds.Error{message: "Unexpected transaction status `:started`"}
    {:disconnect, err, s}
  end

  def checkout(%{sock: {mod, sock}} = s) do
    sock_mod = inspect(mod)

    case :inet.setopts(sock, active: false) do
      :ok ->
        {:ok, s}

      {:error, reason} ->
        msg = "Failed to #{sock_mod}.setops(active: false) due `#{reason}`"
        {:disconnect, %Tds.Error{message: msg}, s}
    end
  end

  @impl DBConnection
  @spec checkin(state :: t) ::
          {:ok, new_state :: t}
          | {:disconnect, Exception.t(), new_state :: t}
  def checkin(%{transaction: :started} = s) do
    err = %Tds.Error{message: "Unexpected transaction status `:started`"}
    {:disconnect, err, s}
  end

  def checkin(%{sock: {mod, sock}} = s) do
    sock_mod = inspect(mod)

    case :inet.setopts(sock, active: :once) do
      :ok ->
        {:ok, s}

      {:error, reason} ->
        msg = "Failed to #{sock_mod}.setops(active: false) due `#{reason}`"
        {:disconnect, %Tds.Error{message: msg}, s}
    end
  end

  @impl DBConnection
  @spec handle_execute(Tds.Query.t(), DBConnection.params(), Keyword.t(), t) ::
          {:ok, Tds.Query.t(), Tds.Result.t(), new_state :: t}
          | {:error | :disconnect, Exception.t(), new_state :: t}
  def handle_execute(
        %Query{handle: handle, statement: statement} = query,
        params,
        opts,
        %{sock: _sock} = s
      ) do
    params = opts[:parameters] || params
    Process.put(:resultset, Keyword.get(opts, :resultset, false))

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
    Process.delete(:resultset)

    unless is_nil(handle) do
      handle_close(query, opts, %{s | state: :executing})
    end
  end

  @impl DBConnection
  @spec handle_prepare(Tds.Query.t(), Keyword.t(), t) ::
          {:ok, Tds.Query.t(), new_state :: t()}
          | {:error | :disconnect, Exception.t(), new_state :: t}
  def handle_prepare(%{statement: statement} = query, opts, s) do
    case Keyword.get(opts, :execution_mode, :prepare_execute) do
      :prepare_execute ->
        params =
          opts[:parameters]
          |> Parameter.prepared_params()

        send_prepare(statement, params, %{s | state: :prepare})

      :executesql ->
        {:ok, query, %{s | state: :executing}}

      execution_mode ->
        message =
          "Unknown execution mode #{inspect(execution_mode)}, please check your config." <>
            "Supported modes are :prepare_execute and :executesql"

        {:error, %Tds.Error{message: message}, s}
    end
  end

  @impl DBConnection
  @spec handle_close(Tds.Query.t(), nil | keyword | map, t()) ::
          {:ok, Tds.Result.t(), new_state :: t()}
          | {:error | :disconnect, Exception.t(), new_state :: t()}
  def handle_close(query, opts, s) do
    params = opts[:parameters]
    send_close(query, params, s)
  end

  @impl DBConnection
  @spec handle_begin(Keyword.t(), t) ::
          {:ok, Tds.Result.t(), new_state :: t}
          | {DBConnection.status(), new_state :: t}
          | {:disconnect, Exception.t(), new_state :: t}
  def handle_begin(opts, %{env: env, transaction: tran} = s) do
    isolation_level = Keyword.get(opts, :isolation_level, :read_committed)

    case Keyword.get(opts, :mode, :transaction) do
      :transaction when tran == nil ->
        payload = [isolation_level: isolation_level]
        send_transaction("TM_BEGIN_XACT", payload, %{s | transaction: :started})

      :savepoint when tran in [:started, :failed] ->
        savepoint = env.savepoint + 1
        env = %{env | savepoint: savepoint}
        s = %{s | transaction: :started, env: env}
        send_transaction("TM_SAVE_XACT", [name: savepoint], s)

      mode when mode in [:transaction, :savepoint] ->
        handle_status(opts, s)
    end
  end

  @impl DBConnection
  @spec handle_commit(Keyword.t(), t) ::
          {:ok, Tds.Result.t(), new_state :: t}
          | {DBConnection.status(), new_state :: t}
          | {:disconnect, Exception.t(), new_state :: t}
  def handle_commit(opts, %{transaction: transaction, env: env} = s) do
    case Keyword.get(opts, :mode, :transaction) do
      :transaction when transaction == :started ->
        send_transaction("TM_COMMIT_XACT", [], %{s | transaction: nil})

      :savepoint when transaction == :started ->
        send_transaction("TM_SAVE_XACT", [name: env.savepoint], s)

      mode when mode in [:transaction, :savepoint] ->
        handle_status(opts, s)
    end
  end

  @impl DBConnection
  @spec handle_rollback(Keyword.t(), t) ::
          {:ok, Tds.Result.t(), new_state :: t}
          | {:idle, new_state :: t}
          | {:disconnect, Exception.t(), new_state :: t}
  def handle_rollback(opts, %{env: env, transaction: transaction} = s) do
    case Keyword.get(opts, :mode, :transaction) do
      :transaction when transaction in [:started, :failed] ->
        env = %{env | savepoint: 0}
        s = %{s | transaction: nil, env: env}
        payload = [name: 0, isolation_level: :read_committed]
        send_transaction("TM_ROLLBACK_XACT", payload, s)

      :savepoint when transaction in [:started, :failed] ->
        payload = [name: env.savepoint]

        send_transaction("TM_ROLLBACK_XACT", payload, %{
          s
          | transaction: :started
        })

      mode when mode in [:transaction, :savepoint] ->
        handle_status(opts, s)
    end
  end

  @impl DBConnection
  @spec handle_status(Keyword.t(), t) ::
          {:idle | :transaction | :error, t}
          | {:disconnect, Exception.t(), t}
  def handle_status(_, %{transaction: transaction} = state) do
    case transaction do
      nil -> {:idle, state}
      :successful -> {:idle, state}
      :started -> {:transaction, state}
      :failed -> {:error, state}
    end
  end

  @impl DBConnection
  @spec handle_fetch(
          Query.t(),
          cursor :: any(),
          opts :: Keyword.t(),
          state :: t()
        ) ::
          {:cont | :halt, Tds.Result.t(), new_state :: t()}
          | {:error | :disconnect, Exception.t(), new_state :: t()}
  def handle_fetch(_query, _cursor, _opts, state) do
    {:error, Tds.Error.exception("Cursor is not supported by TDS"), state}
  end

  @impl DBConnection
  @spec handle_deallocate(
          query :: Query.t(),
          cursor :: any,
          opts :: Keyword.t(),
          state :: t()
        ) ::
          {:ok, Tds.Result.t(), new_state :: t()}
          | {:error | :disconnect, Exception.t(), new_state :: t()}
  def handle_deallocate(_query, _cursor, _opts, state) do
    {:error, Tds.Error.exception("Cursor operations are not supported in TDS"),
     state}
  end

  @impl DBConnection
  @spec handle_declare(
          Query.t(),
          params :: any,
          opts :: Keyword.t(),
          state :: t
        ) ::
          {:ok, Query.t(), cursor :: any, new_state :: t}
          | {:error | :disconnect, Exception.t(), new_state :: t}
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
          |> Enum.chunk_every(2)
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
        error(%Tds.Error{message: "Instance #{opts[:instance]} not found"}, %{
          s
          | usock: nil
        })

      serv ->
        {port, _} = Integer.parse(serv[:tcp])
        {:ok, %{s | opts: opts, itcp: port, usock: nil}}
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
    Logger.error(fn ->
      "Unhandled message! \n\n" <>
        "  Tds.Protocol.hand_info/2 \n\n" <>
        "    Arg #1 \n" <>
        inspect(msg) <>
        "    Arg #2 \n" <>
        inspect(s)
    end)

    {:ok, s}
  end

  defp decode(packet_data, %{state: state} = s) do
    {msg, s} = parse(state, packet_data, s)

    case message(state, msg, s) do
      {:ok, s} ->
        # message processed, reset header and msg buffer, then process
        # tail
        {:ok, s}

      {:ok, _result, s} ->
        # send_query returns a result
        {:ok, s}

      {:error, _, _} = err ->
        err
    end
  end

  defp flush(%{sock: sock} = s) do
    receive do
      {:tcp, ^sock, data} ->
        _ = decode(data, s)
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
        {:ok, %{s | state: :ready}}

      err ->
        err
    end
  end

  defp send_query(statement, s) do
    msg = msg_sql(query: statement)

    case msg_send(msg, %{s | state: :executing}) do
      {:ok, %{result: result} = s} ->
        {:ok, result, s}

      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}

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

    case msg_send(msg, %{s | state: :prepare}) do
      {:ok, %{query: query} = s} ->
        {:ok, %{query | statement: statement}, %{s | state: :executing}}

      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}

      err ->
        err
    end
  end

  def send_transaction(command, payload, s) do
    msg =
      msg_transmgr(
        command: command,
        name: Keyword.get(payload, :name),
        isolation_level: Keyword.get(payload, :isolation_level)
      )

    case msg_send(msg, %{s | state: :transaction_manager}) do
      {:ok, %{result: result} = s} ->
        {:ok, result, s}

      {:error, err} ->
        {:disconnect, err, s}

      {:error, err, s} ->
        {:disconnect, err, s}
    end
  end

  @spec send_param_query(Tds.Query.t(), list(), t) ::
          {:error, any()}
          | {:ok, %{optional(:result) => none()}}
          | {:disconnect, any(), %{env: any(), sock: {any(), any()}}}
          | {:error, Tds.Error.t(), %{pak_header: <<>>, tail: <<>>}}
          | {:ok, any(), %{result: any(), state: :ready}}
  defp send_param_query(
         %Query{handle: handle, statement: statement} = _,
         params,
         %{transaction: :started} = s
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

      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}

      err ->
        err
    end
  end

  defp send_param_query(
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

      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}

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

      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}

      err ->
        err
    end
  end

  def message(
        :login,
        msg_loginack(redirect: %{hostname: host, port: port}),
        %{opts: opts} = s
      ) do
    # we got an ENVCHANGE:redirection token, we need to disconnect and start over with new server
    disconnect("redirected", s)

    new_opts =
      opts
      |> Keyword.put(:hostname, host)
      |> Keyword.put(:port, port)

    connect(new_opts)
  end

  def message(:login, msg_loginack(), %{opts: opts} = s) do
    state = %{s | opts: clean_opts(opts)}

    opts
    |> conn_opts()
    |> IO.iodata_to_binary()
    |> send_query(state)
  end

  def message(:executing, msg_result(set: set), s) do
    resultset? = Process.get(:resultset, false)

    result =
      case {set, resultset?} do
        {r, true} -> r
        {r, false} -> List.first(r) || %Tds.Result{rows: nil}
        {[h | _t], _false} -> h
      end

    {:ok, mark_ready(%{s | result: result})}
  end

  def message(:transaction_manager, msg_trans(), s) do
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}

    {:ok, %{s | state: :ready, result: result}}
  end

  def message(:prepare, msg_prepared(params: params), %{} = s) do
    handle =
      params
      |> Enum.find(%{}, &(&1.name == "@handle" and &1.direction == :output))
      |> Map.get(:value, nil)

    result = %Tds.Result{columns: [], rows: [], num_rows: 0}
    query = %Tds.Query{handle: handle}

    {:ok, mark_ready(%{s | result: result, query: query})}
  end

  ## Error
  def message(_, msg_error(error: e), %{} = s) do
    error = %Tds.Error{mssql: e}
    {:error, error, mark_ready(s)}
  end

  ## ATTN Ack
  def message(:attn, _, %{} = s) do
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}

    {:ok, %{s | statement: "", state: :ready, result: result}}
  end

  defp mark_ready(%{state: _} = s) do
    %{s | state: :ready}
  end

  # Send Command To Sql Server
  defp login_send(msg, %{sock: {mod, sock}, env: env} = s) do
    paks = encode_msg(msg, env)

    Enum.each(paks, fn pak ->
      mod.send(sock, pak)
    end)

    case msg_recv(s) do
      {:disconnect, ex, s} ->
        {:error, ex, s}

      buffer ->
        buffer
        |> IO.iodata_to_binary()
        |> decode(%{s | state: :login})
    end
  end

  defp msg_send(
         msg,
         %{sock: {mod, sock}, env: env, state: state, opts: opts} = s
       ) do
    :inet.setopts(sock, active: false)

    opts
    |> Keyword.get(:use_elixir_calendar_types, false)
    |> use_elixir_calendar_types()

    {t_send, _} =
      :timer.tc(fn ->
        msg
        |> encode_msg(env)
        |> Enum.each(&mod.send(sock, &1))
      end)

    {t_recv, {t_decode, result}} =
      :timer.tc(fn ->
        case msg_recv(s) do
          {:disconnect, _ex, _s} = res ->
            {0, res}

          buffer ->
            :timer.tc(fn ->
              buffer
              |> IO.iodata_to_binary()
              |> decode(s)
            end)
        end
      end)

    stm = Map.get(s, :query)

    if Keyword.get(s.opts, :trace, false) == true do
      Logger.debug(fn ->
        "[trace] [Tds.Protocod.msg_send/2] " <>
          "state=#{inspect(state)} " <>
          "send=#{Tds.Perf.to_string(t_send)} " <>
          "receive=#{Tds.Perf.to_string(t_recv - t_decode)} " <>
          "decode=#{Tds.Perf.to_string(t_decode)}" <>
          "\n" <>
          "#{inspect(stm)}"
      end)
    end

    result
  end

  defp msg_recv(%{sock: {mod, pid}} = s) do
    case mod.recv(pid, 0) do
      {:ok, pkg} ->
        pkg
        |> next_tds_pkg([])
        |> msg_recv(s)

      {:error, error} ->
        {:disconnect,
         %Tds.Error{
           message: "Connection failed to receive packet due #{inspect(error)}"
         }, s}
    end
  catch
    {:error, error} -> {:disconnect, error, s}
  end

  defp msg_recv({:done, buffer, _}, _s) do
    Enum.reverse(buffer)
  end

  defp msg_recv({:more, buffer, more, last?}, %{sock: {mod, pid}} = s) do
    take = if last?, do: more, else: 0

    case mod.recv(pid, take) do
      {:ok, pkg} ->
        next_tds_pkg(pkg, buffer, more, last?)
        |> msg_recv(s)

      {:error, error} ->
        throw({:error, error})
    end
  end

  defp msg_recv({:more, buffer, unknown_pkg}, %{sock: {mod, pid}} = s) do
    case mod.recv(pid, 0) do
      {:ok, pkg} ->
        unknown_pkg
        |> Kernel.<>(pkg)
        |> next_tds_pkg(buffer)
        |> msg_recv(s)

      {:error, error} ->
        throw({:error, error})
    end
  end

  defp next_tds_pkg(pkg, buffer) do
    case pkg do
      <<0x04, 0x01, size::int16, _::int32, chunk::binary>> ->
        more = size - 8
        next_tds_pkg(chunk, buffer, more, true)

      <<0x04, 0x00, size::int16, _::int32, chunk::binary>> ->
        more = size - 8
        next_tds_pkg(chunk, buffer, more, false)

      unknown_pkg ->
        {:more, buffer, unknown_pkg}
    end
  end

  defp next_tds_pkg(pkg, buffer, more, true) do
    case pkg do
      <<chunk::binary(more, 8), tail::binary>> ->
        {:done, [chunk | buffer], tail}

      <<chunk::binary>> ->
        more = more - byte_size(chunk)
        {:more, [chunk | buffer], more, true}
    end
  end

  defp next_tds_pkg(pkg, buffer, more, false) do
    case pkg do
      <<chunk::binary(more, 8), tail::binary>> ->
        next_tds_pkg(tail, [chunk | buffer])

      <<chunk::binary>> ->
        more = more - byte_size(chunk)
        {:more, [chunk | buffer], more, false}
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
    |> append_opts(opts, :set_cursor_close_on_commit)
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
          ArgumentError,
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
          ArgumentError,
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
          ArgumentError,
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
          ArgumentError,
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
          ArgumentError,
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
          ArgumentError,
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
          ArgumentError,
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
          ArgumentError,
          "set_allow_snapshot_isolation: #{inspect(val)} is an invalid value, " <>
            "should be either :on, :off, nil"
        )
    end
  end

  defp append_opts(conn, opts, :set_cursor_close_on_commit) do
    case Keyword.get(opts, :set_cursor_close_on_commit) do
      val when val in [:on, :off] ->
        val = val |> Atom.to_string() |> String.upcase()
        conn ++ ["SET CURSOR_CLOSE_ON_COMMIT #{val}; "]

      nil ->
        conn

      val ->
        raise(
          ArgumentError,
          "set_cursor_close_on_commit: #{inspect(val)} is an invalid value, " <>
            "should be one of should be either :on, :off or nil"
        )
    end
  end
end
