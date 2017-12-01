defmodule Tds.Protocol do

  import Tds.BinaryUtils
  import Tds.Messages
  import Tds.Utils

  alias Tds.Parameter
  alias Tds.Query

  require Logger

  @behaviour DBConnection

  @timeout 5000
  @max_packet 4 * 1024
  @sock_opts [packet: :raw, mode: :binary, active: false, recbuf: 4096]

  defstruct [
    sock: nil,
    usock: nil,
    itcp: nil,
    opts: nil,
    state: :ready,
    tail: "", #only has non-empty value when waiting for more data
    pak_header: "", #current tds packet header
    pak_data: "", #current tds message holding previous tds packets
    result: nil,
    query: nil,
    transaction: nil,
    env: %{trans: <<0x00>>}
  ]

  def connect(opts) do
    opts = opts
    |> Keyword.put_new(:username, System.get_env("MSSQLUSER") || System.get_env("USER"))
    |> Keyword.put_new(:password, System.get_env("MSSQLPASSWORD"))
    |> Keyword.put_new(:instance, System.get_env("MSSQLINSTANCE"))
    |> Keyword.put_new(:hostname, System.get_env("MSSQLHOST") || "localhost")
    |> Enum.reject(fn {_k,v} -> is_nil(v) end)

    _timeout = opts[:timeout] || @timeout
    s = %__MODULE__{}

    case opts[:instance] do
      nil -> connect(opts, s)
      _instance ->
        case instance(opts, s) do
          {:ok, s} -> connect(opts, s)
          err -> {:error, err}
        end
    end
  end

  def disconnect(_err, %{sock: {mod, sock}} = s) do
    # If socket is active we flush any socket messages so the next
    # socket does not get the messages.
    _ = flush(s)
    mod.close(sock)
  end

  @spec ping(any) :: {:ok, any} | {:disconnect, Exception.t, any}
  def ping(state) do
    case send_query(~s{SELECT 'pong' as [msg]}, state) do
      {:ok, _, s} ->
        {:ok, s}
      {:disconnect, :closed, s} ->
        {:disconnect, %Tds.Error{message: "Connection closed."}, s}
      {:error, err, s} ->
        err = cond do
          Exception.exception?(err) -> err
          true                      -> %Tds.Error{message: inspect(err)}
        end
        {:disconnect, err, s}
      any ->
        any
    end
  end

  def checkout(%{sock: {_mod, sock}} = s) do
    :ok = :inet.setopts(sock, [active: false])

    {:ok, s}
  end

  def checkin(%{sock: {_mod, sock}} = s) do
    :ok = :inet.setopts(sock, [active: :once])

    {:ok, s}
  end

  def handle_execute(%Query{statement: statement} = query, params, opts, %{sock: _sock} = s) do
    params = opts[:parameters] || params
    proc = opts[:proc] || nil

    cond do
      params != [] and is_nil(proc) -> send_param_query(query, params, s)
      not is_nil(proc) -> send_proc(proc, params, s)
      true -> send_query(statement, s)
    end
  end

  def handle_prepare(%{statement: statement}, opts, %{sock: _sock} = s) do
    params = opts[:parameters]
    |> Parameter.prepared_params

    send_prepare(statement, params, s)
  end

  def handle_close(query, opts, %{sock: _sock} = s) do
    params = opts[:parameters]

    send_close(query, params, s)
  end

  def handle_begin(_opts, %{sock: _sock} = s) do
    send_transaction("TM_BEGIN_XACT", %{s | transaction: :started})
  end

  def handle_commit(_opts, %{transaction: status} = s) do
    case status do
      :failed ->
        handle_rollback([], s)
      _ ->
        send_transaction("TM_COMMIT_XACT", %{s | transaction: :successful})
    end
  end

  def handle_rollback(_opts, %{sock: _sock} = s) do
    send_transaction("TM_ROLLBACK_XACT", %{s | transaction: :failed})
  end

  # CONNECTION

  defp instance(opts, s) do
    host      = Keyword.fetch!(opts, :hostname)
    host      = if is_binary(host), do: String.to_charlist(host), else: host

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
    host      = Keyword.fetch!(opts, :hostname)
    host      = if is_binary(host), do: String.to_charlist(host), else: host
    port      = s.itcp || opts[:port] || System.get_env("MSSQLPORT") || 1433
    {port, _}      = if is_binary(port), do: Integer.parse(port), else: {port, nil}
    timeout   = opts[:timeout] || @timeout
    sock_opts = @sock_opts ++ (opts[:socket_options] || [])

    s = %{s | opts: opts}

    case :gen_tcp.connect(host, port, sock_opts, timeout) do
      {:ok, sock} ->
        #s = put_in s.sock, {:gen_tcp, sock}

        # A suitable :buffer is only set if :recbuf is included in
        # :socket_options.
        {:ok, [sndbuf: sndbuf, recbuf: recbuf, buffer: buffer]} =
          :inet.getopts(sock, [:sndbuf, :recbuf, :buffer])

        buffer = buffer
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

  defp parse_udp({_, 1434, <<_head::binary-3, data::binary>>}, %{opts: opts, usock: sock} = s) do
    :gen_udp.close(sock)
    server = String.split(data, ";;")
      |> Enum.slice(0..-2)
      |> Enum.reduce([], fn(str, acc) ->
        server = String.split(str, ";")
          |> Enum.chunk(2)
          |> Enum.reduce([], fn ([k,v], acc) ->
            k = k
              |> String.downcase
              |> String.to_atom
            Keyword.put_new(acc, k, v)
          end)
        [server | acc]
      end)
      |> Enum.find(fn(s) ->
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

  def handle_info({:udp_error, _, :econnreset}, _s) do
    raise "Tds encountered an error while connecting to the Sql Server Browser: econnreset"
  end

  def handle_info({:tcp, _, _data}, %{sock: {mod, sock}, opts: opts, state: :prelogin} = s) do
    case mod do
      :gen_tcp -> :inet.setopts(sock, active: false)
      :ssl     -> :ssl.setopts(sock, active: false)
    end

    login(%{s | opts: opts, sock: {mod, sock}})
  end

  def handle_info({tag, _}, s) when tag in [:tcp_closed, :ssl_closed] do
    error(%Tds.Error{message: "tcp closed"}, s)
  end

  def handle_info({tag, _, reason}, s) when tag in [:tcp_error, :ssl_error] do
    error(%Tds.Error{message: "tcp error: #{reason}"}, s)
  end

  def handle_info(msg, s) do
    Logger.debug "Unhandled info: #{inspect msg}"

    {:ok, s}
  end


  #no data to process
  defp new_data(<<_data::0>>, s) do
    {:ok, s}
  end

  #DONE_ATTN The DONE message is a server acknowledgement of a client ATTENTION message.
  defp new_data(<<0xFD, 0x20, _cur_cmd::binary(2), 0::size(8)-unit(8), _tail::binary>>, %{state: :attn} = s) do
    s = %{s | pak_header: "", pak_data: "", tail: ""}
    message(:attn, :attn, s)
  end

  #shift 8 bytes while in attention state, Protocol updates state
  defp new_data(<<_b::size(1)-unit(8), tail::binary>>, %{state: :attn} = s) do
    new_data(tail, s)
  end

  #no packet header yet
  defp new_data(<<data::binary>>, %{pak_header: ""} = s) do
    if byte_size(data) >= 8 do
      #assume incoming data starts with packet header, if it's long enough
      #Logger.debug "S: #{inspect s}"
      <<pak_header::binary(8), tail::binary>> = data
      new_data(tail, %{s | pak_header: pak_header})
    else
      #have no packet header yet, wait for more data
      {:ok, %{s | tail: data}}
    end
  end

  defp new_data(<<data::binary>>, %{state: state, pak_header: pak_header, pak_data: pak_data} = s) do
    <<type::int8, status::int8, size::int16, _head_rem::int32>> = pak_header
    size = size - 8 #size includes packet header
    case data do
      <<package::binary(size), tail::binary>> ->
        #satisfied size specified in packet header
        case status do
          1 ->
            #status 1 means last packet of message
            #TODO Messages.parse does not use pak_header

            msg = parse(state, type, pak_header, pak_data <> package)

            case message(state, msg, s) do
              {:ok, s} ->
                #message processed, reset header and msg buffer, then process tail
                new_data(tail, %{s | pak_header: "", pak_data: ""})
              {:ok, _result, s} ->
                # send_query returns a result
                new_data(tail, %{s | pak_header: "", pak_data: ""})
              {:error, _, _} = err ->
                err
            end
          _ ->
            #not the last packet of message, more packets coming with new packet header
            new_data(tail, %{s | pak_header: "", pak_data: pak_data <> package})
        end
      data ->
        #size specified in packet header still unsatisfied, wait for more data
        {:ok, %{s | tail: data, pak_header: pak_header}}
    end
  end

  defp flush(%{sock: sock} = s) do
    receive do
      {:tcp, ^sock, _data} ->
        new_data(sock, s)
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
      :ok ->
        {:noreply,  %{s | state: :prelogin}}
      {:error, reason, s} ->
        error(%Tds.Error{message: "tcp send: #{reason}"}, s)
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
      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}
      err ->
        err
    end
  end

  def send_prepare(statement, params, s) do
    params = [
      %Tds.Parameter{name: "@handle", type: :integer, direction: :output, value: nil},
      %Tds.Parameter{name: "@params", type: :string, value: params},
      %Tds.Parameter{name: "@stmt", type: :string, value: statement}
    ]

    msg = msg_rpc(proc: :sp_prepare, query: statement, params: params)

    case msg_send(msg, s) do
      {:ok, %{query: query} = s} ->
        {:ok, %{query | statement: statement}, %{s | state: :ready}}
      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}
      err ->
        err
    end
  end

  def send_transaction(command, s) do
    msg = msg_transmgr(command: command)

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}
      err ->
        err
    end
  end

  #def send_command(statement, s) do
  #  Logger.debug "CALLED send_command/2"
  #  Logger.debug "STATEMENT: #{inspect statement}"

  #  msg = msg_sql(query: statement)
  #  simple_send(msg, s)

  #  {:ok, %{s | statement: nil, state: :ready}}
  #end

  def send_proc(proc, params, s) do
    params = Tds.Parameter.prepare_params(params)
    msg = msg_rpc(proc: proc, params: params)

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}
      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}
      err ->
        err
    end
  end

  def send_param_query(%Query{handle: handle} = _query, params, %{transaction: :started} = s) do
    params = [
      %Tds.Parameter{name: "@handle", type: :integer, direction: :input, value: handle}
      | Tds.Parameter.prepare_params(params)
    ]

    # msg = msg_rpc(proc: :sp_executesql, params: params)
    msg = msg_rpc(proc: :sp_execute, params: params)

    case msg_send(msg, s) do
      {:ok, %{result: result} = s} ->
        {:ok, result, %{s | state: :ready}}
      {:error, err, %{transaction: :started} = s} ->
        {:error, err, %{s | transaction: :failed}}
      err ->
        err
    end
  end
  def send_param_query(%Query{handle: handle} = _query, params, s) do
    params = [
      %Tds.Parameter{name: "@handle", type: :integer, direction: :input, value: handle}
      | Tds.Parameter.prepare_params(params)
    ]

    # msg = msg_rpc(proc: :sp_executesql, params: params)
    msg = msg_rpc(proc: :sp_execute, params: params)

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
      %Tds.Parameter{name: "@handle", type: :integer, direction: :input, value: handle}
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

  #def send_proc(proc, params, s) do
  #  msg = msg_rpc(proc: proc, params: params)
  #  case send_to_result(msg, s) do
  #    {:ok, s} ->
  #      {:ok, %{s | statement: nil, state: :executing}}
  #    err ->
  #      err
  #  end
  #end

  #def send_attn(s) do
  #  msg = msg_attn()
  #  simple_send(msg, s)

  #  {:ok, %{s | statement: nil, state: :attn}}
  #end

  ## SERVER Packet Responses

  def message(:prelogin, _state) do

  end

  def message(:login, msg_login_ack(), %{opts: opts, sock: {_mod, _sock}} = s) do
    s = %{s | opts: clean_opts(opts)}

    send_query("""
          SET ANSI_NULLS ON;
          SET QUOTED_IDENTIFIER ON;
          SET CURSOR_CLOSE_ON_COMMIT OFF;
          SET ANSI_NULL_DFLT_ON ON;
          SET IMPLICIT_TRANSACTIONS OFF;
          SET ANSI_PADDING ON;
          SET ANSI_WARNINGS ON;
          SET CONCAT_NULL_YIELDS_NULL ON;
          SET TEXTSIZE 2147483647;
          ALTER DATABASE #{opts[:database]} SET ALLOW_SNAPSHOT_ISOLATION ON;
        """, s)
  end

  ## executing

  def message(:executing, msg_sql_result(columns: columns, rows: rows, done: done), %{} = s) do
    columns =
    if columns != nil do
      Enum.reduce(columns, [], fn (col, acc) -> [col[:name]|acc] end) |> Enum.reverse
    else
      columns
    end
    num_rows = done.rows;
    # rows are correctly orrdered when they were parsed, so below is not needed anymore
    # rows =
    # if rows != nil, do:  Enum.reverse(rows), else: rows
    rows = if num_rows == 0 && rows == nil, do: [], else: rows

    result = %Tds.Result{columns: columns, rows: rows, num_rows: num_rows}

    { :ok, %{s | state: :executing, result: result} }
  end

  def message(:executing, msg_trans(trans: trans), %{} = s) do
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}

    { :ok, %{s | state: :ready, result: result, env: %{trans: trans}} }
  end

  def message(:executing, msg_prepared(params: params), %{} = s) do
    {"@handle", handle} = params

    result = %Tds.Result{columns: [], rows: [], num_rows: 0}
    query = %Tds.Query{handle: handle}

    { :ok, %{s | state: :ready, result: result, query: query} }
  end

  ## Error
  def message(_, msg_error(e: e), %{} = s) do
    error = %Tds.Error{mssql: e}
    { :error, error, %{s | pak_header: "", tail: ""} }
  end

  ## ATTN Ack
  #def message(:attn, _, %{} = s) do
  #  result = %Tds.Result{columns: [], rows: [], num_rows: 0}

  #  { :ok, %{s | statement: "", state: :ready, result: result} }
  #end

  #defp simple_send(msg, %{sock: {mod, sock}, env: env}) do
  #  paks = encode_msg(msg, env)

  #  Enum.each(paks, fn(pak) ->
  #    mod.send(sock, pak)
  #  end)
  #end

  defp msg_send(msg, %{sock: {mod, sock}, env: env} = s) do
    :inet.setopts(sock, active: false)

    paks = encode_msg(msg, env)
    Enum.each(paks, fn(pak) ->
      mod.send(sock, pak)
    end)

    case msg_recv(<<>>, s) do
      {:disconnect, _ex , _s}=res ->
        res
      buffer ->
        new_data(buffer, %{s | state: :executing, pak_header: ""})
    end

  end

  defp msg_recv(buffer, %{sock: {mod, sock}} = s) do
    #IO.puts("buffer: #{inspect buffer}")
    case mod.recv(sock, 8) do
      # there is more tds packages after this one
      {:ok, <<_type::int8, 0x00, length::int16, _spid::int16, _package::int8, _window::int8>> = header}  ->
        buffer <> header
        |> package_recv(s, length - 8)
        |> msg_recv(s)
      # this heder belongs to last package
      {:ok, <<_type::int8, 0x01, length::int16, _spid::int16, _package::int8, _window::int8>> = header} ->
        #IO.puts("header: #{inspect header}")
        buffer <> header
        |> package_recv(s, length - 8)
      {:ok, _} ->
        raise("Other statuses todo!")
      {:error, exception} ->
        {:disconnect, exception, s}
    end
  end

  defp package_recv(buffer, %{sock: {mod, sock}} = s, length) do
    case mod.recv(sock, min(length, @max_packet)) do
      {:ok, data} when byte_size(data) < length ->
        length = length - byte_size(data)
        buffer <> data
        |> package_recv(s, length)
      {:ok, data} ->
        buffer <> data
      {:error, exception} ->
        {:disconnect, exception, s}
    end
  end

  # defp msg_cast(msg, %{sock: {mod, sock}, env: env} = s) do
  #   :inet.setopts(sock, active: false)

  #   paks = encode_msg(msg, env)
  #   Enum.each(paks, fn(pak) ->
  #     mod.send(sock, pak)
  #   end)
  #   # NOTE: this method can not be used since it is not receiving packages from SQL server!
  #   # TODO: add :gen_tcp.recv/flush since it should flush next package if there is such case where we don't care about
  #   # what package contains.
  #   {:ok, s}
  # end

  defp login_send(msg, %{sock: {mod, sock}, env: env} = s) do
    paks = encode_msg(msg, env)
    Enum.each(paks, fn(pak) ->
      mod.send(sock, pak)
    end)

    case msg_recv(<<>>, s) do
      {:disconnect, ex , s} ->
        {:error, ex, s}
      buffer ->
        new_data(buffer, %{s | state: :login})
    end
  end

  #defp send_to_result(msg, s) do
  #  case msg_send(msg, s) do
  #    :ok ->
  #      {:ok, s}
  #    {:error, reason} ->
  #      {:error, %Tds.Error{message: "tcp send: #{reason}"} , s}
  #  end
  #end
  #
  #case send_attn(%{s | pak_header: "", pak_data: "", tail: "", state: :attn}) do
  #  {:ok, s} ->
  #    {:ok, s}
  #  err ->
  #    {:disconnect, %Tds.Error{message: "attn error: #{err}"}}
  #end

  defp clean_opts(opts) do
    Keyword.put(opts, :password, :REDACTED)
  end

end
