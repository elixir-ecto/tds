defmodule Tds.Connection do
  use GenServer
  alias Tds.Protocol
  alias Tds.Messages
  require Logger

  import Tds.BinaryUtils
  import Tds.Utils

  @timeout :infinity

  ### PUBLIC API ###

  def start_link(opts) do
    case GenServer.start_link(__MODULE__, []) do
      {:ok, pid} ->
        timeout = opts[:connect_timeout] || @timeout
        case GenServer.call(pid, {:connect, opts}, timeout) do
          :ok -> {:ok, pid}
          err -> {:error, err}
        end
      err -> err
    end
  end

  def stop(pid, opts \\ []) do
    GenServer.call(pid, :stop, opts[:timeout] || @timeout)
  end

  def query(pid, statement, params, opts \\ []) do
    #Logger.debug "Query: #{statement}"
    message = {:query, statement, params, opts}
    timeout = opts[:timeout] || @timeout
    call_proc(pid, message, timeout)
  end

  def proc(pid, proc, params, opts \\ []) do
    message = {:proc, proc, params, opts}
    timeout = opts[:timeout] || @timeout
    call_proc(pid, message, timeout)
  end

  defp call_proc(pid, message, timeout) do
    case GenServer.call(pid, message, timeout) do
      %Tds.Result{} = res -> {:ok, res}
      %Tds.Error{} = err  ->
        #Logger.debug "Query Error"
        {:error, err}
    end
  end

  ### GEN_SERVER CALLBACKS ###

  def init([]) do
    {:ok, %{sock: nil, opts: nil, state: :ready, tail: "", queue: :queue.new, bootstrap: false, statement: nil, pak_header: "", pak_data: ""}}
  end

  def handle_call(:stop, from, s) do
    GenServer.reply(from, :ok)
    {:stop, :normal, s}
  end

  def handle_call({:connect, opts}, from, %{queue: queue} = s) do
    host      = opts[:hostname] || System.get_env("MSSQLHOST")
    host      = if is_binary(host), do: String.to_char_list(host), else: host
    port      = opts[:port] || System.get_env("MSSQLPORT") || 1433
    timeout   = opts[:connect_timeout] || @timeout
    sock_opts = [{:active, :once}, :binary, {:packet, :raw}, {:delay_send, false}]

    case :gen_tcp.connect(host, port, sock_opts, timeout) do
      {:ok, sock} ->
        queue = :queue.in({{:connect, opts}, from, nil}, queue)
        s = %{s | opts: opts, sock: {:gen_tcp, sock}, queue: queue}
        #Protocol.prelogin(s)
        Protocol.login(%{s | opts: opts, sock: {:gen_tcp, sock}})
      {:error, reason} ->
        {:stop, :normal, %Tds.Error{message: "tcp connect: #{reason}"}, s}
    end
  end

  def handle_call(command, from, %{state: state, queue: queue} = s) do
    #Logger.debug "Handle Call Command"
    #Logger.debug "State: #{state}"
    # Assume last element in tuple is the options
    timeout = elem(command, tuple_size(command)-1)[:timeout] || @timeout
    unless timeout == :infinity do
      timer_ref = :erlang.start_timer(timeout, self(), :command)
    end

    queue = :queue.in({command, from, timer_ref}, queue)
    s = %{s | queue: queue}
    if state == :ready do
      case next(s) do
        {:ok, s} -> {:noreply, s}
        {:error, error, s} -> error(error, s)
      end
    else
      {:noreply, s}
    end
  end

  def handle_info({:tcp, _, _data}, %{sock: {mod, sock}, opts: opts, state: :prelogin} = s) do
    #Logger.debug "PreLogin"

    case mod do
      :gen_tcp -> :inet.setopts(sock, active: :once)
      :ssl     -> :ssl.setopts(sock, active: :once)
    end
    Protocol.login(%{s | opts: opts, sock: {mod, sock}})
  end

  def handle_info({tag, _, data}, %{sock: {mod, sock}, tail: tail} = s)
      when tag in [:tcp, :ssl] do
    #Logger.debug "Data In"

    case new_data(tail <> data, %{s | tail: ""}) do
      {:ok, s} ->
        case mod do
          :gen_tcp -> :inet.setopts(sock, active: :once)
          :ssl     -> :ssl.setopts(sock, active: :once)
        end
        {:noreply, s}
      {:error, error, s} ->
        error(error, s)
    end
  end

  def handle_info({tag, _}, s) when tag in [:tcp_closed, :ssl_closed] do
    #Logger.debug "TCP Closed: #{IO.inspect tag}"
    error(%Tds.Error{message: "tcp closed"}, s)
  end

  def handle_info({tag, _, reason}, s) when tag in [:tcp_error, :ssl_error] do
    #Logger.debug "TCP Error: #{IO.inspect reason}"
    error(%Tds.Error{message: "tcp error: #{reason}"}, s)
  end

  def new_query(statement, params, %{queue: queue} = s) do
    command = {:query, statement, params, []}
    {{:value, {_command, from, timer}}, queue} = :queue.out(queue)
    queue = :queue.in_r({command, from, timer}, queue)
    command(command, %{s | queue: queue})
  end

  def next(%{queue: queue} = s) do
    case :queue.out(queue) do
      {{:value, {command, _from, _timer}}, _queue} ->
        #Logger.debug "Calling Command"
        command(command, s)
      {:empty, _queue} ->
        {:ok, s}
    end
  end

  defp command({:query, statement, params, _opts}, s) do
    if params != [] do
      Protocol.send_param_query(statement, params, s)
    else
      Protocol.send_query(statement, s)
    end
  end

  defp command({:proc, proc, params, _opts}, s) do
    Protocol.send_proc(proc, params, s)
  end
  
  defp new_data(<<_data::0>>, s), do: {:ok, s}
  defp new_data(<<packet::binary>>, %{state: state, pak_data: buf_data, pak_header: buf_header, tail: tail} = s) do

    <<type::int8, status::int8, size::int16, head_rem::int32, data::binary>> = tail <> packet
    if buf_header == "" do

      buf_header = <<type::int8, status::int8, size::int16, head_rem::int32>>
    else
      data = tail <> packet
    end

    <<type::int8, status::int8, size::int16, _head_rem::int32>> = buf_header
    size = size - 8

    case data do
      <<data :: binary(size), tail :: binary>> ->
        case status do
          1 ->
            #Logger.debug "Final Packet"
            #Logger.debug "#{Tds.Utils.to_hex_string buf_header<>data}"
            msg = Messages.parse(state, type, buf_header, buf_data<>data)
            case Protocol.message(state, msg, s) do
              {:ok, s} -> new_data(tail, %{s | pak_header: "", pak_data: "", tail: tail})
              {:error, _, _} = err -> err
            end
          _ ->
            #Logger.debug "Continuing Packet"
            #Logger.debug "Data: #{Tds.Utils.to_hex_string data}"
            {:ok, %{s | pak_data: buf_data <> data, pak_header: "", tail: tail}}
        end
      _ ->
        {:ok, %{s | tail: tail <> data, pak_header: buf_header}}
    end
  end

  # defp new_data(data, %{tail: tail, pak_header: ""} = s) do
  #   Logger.debug "Data to Tail"
  #   {:ok, %{s | tail: tail <> data}}
  # end

end
