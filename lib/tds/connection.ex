defmodule Tds.Connection do
  use GenServer
  alias Tds.Protocol
  alias Tds.Messages

  import Tds.BinaryUtils
  import Tds.Utils

  @timeout 5000

  ### PUBLIC API ###

  def start_link(opts) do
    opts = opts
      |> Keyword.put_new(:username, System.get_env("MSSQLUSER") || System.get_env("USER"))
      |> Keyword.put_new(:password, System.get_env("MSSQLPASSWORD"))
      |> Keyword.put_new(:instance, System.get_env("MSSQLINSTANCE"))
      |> Keyword.put_new(:hostname, System.get_env("MSSQLHOST") || "localhost")
      |> Enum.reject(fn {_k,v} -> is_nil(v) end)
    case GenServer.start_link(__MODULE__, []) do
      {:ok, pid} ->
        timeout = opts[:timeout] || @timeout
        case opts[:instance] do
          nil ->
            case GenServer.call(pid, {:connect, opts}, timeout) do
              :ok -> {:ok, pid}
              err -> {:error, err}
            end
          _instance ->
            case GenServer.call(pid, {:instance, opts}, timeout) do
              :ok ->
                case GenServer.call(pid, {:connect, opts}, timeout) do
                  :ok -> {:ok, pid}
                  err -> {:error, err}
                end
              err ->
                {:error, err}
            end
        end
      err -> err
    end
  end

  def stop(pid, opts \\ []) do
    GenServer.call(pid, :stop, opts[:timeout] || @timeout)
  end

  def query(pid, statement, params, opts \\ []) do

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
        {:error, err}
    end
  end

  def attn(pid, opts \\ []) do
    timeout = opts[:timeout] || @timeout
    case GenServer.call(pid, :attn, timeout) do
      %Tds.Result{} = res ->
        {:ok, res}
      %Tds.Error{} = err  ->
        {:error, err}
    end
  end

  ### GEN_SERVER CALLBACKS ###

  def init([]) do
    {:ok, %{
      sock: nil,
      usock: nil,
      itcp: nil,
      ireq: nil,
      opts: nil,
      state: :ready,
      tail: "",
      queue: :queue.new,
      attn_timer: nil,
      statement: nil,
      pak_header: "",
      pak_data: "",
      env: %{trans: <<0x00>>}}}
  end

  def handle_call(:stop, from, s) do
    GenServer.reply(from, :ok)
    {:stop, :normal, s}
  end

  def handle_call({:instance, opts}, from, s) do
    host      = Keyword.fetch!(opts, :hostname)
    host      = if is_binary(host), do: String.to_char_list(host), else: host

    case :gen_udp.open(0, [:binary, {:active, true}, {:reuseaddr, true}]) do
      {:ok, sock} ->
        :gen_udp.send(sock, host, 1434, <<3>>)
        {:noreply, %{s | opts: opts, ireq: from, usock: sock}}
      {:error, error} ->
         error(%Tds.Error{message: "udp connect: #{error}"}, s)
    end
  end

  def handle_call({:connect, opts}, from, %{queue: queue} = s) do
    host      = Keyword.fetch!(opts, :hostname)
    host      = if is_binary(host), do: String.to_char_list(host), else: host
    port      = s[:itcp] || opts[:port] || System.get_env("MSSQLPORT") || 1433
    if is_binary(port), do: {port, _} = Integer.parse(port)
    timeout   = opts[:timeout] || @timeout
    sock_opts = [{:active, :once}, :binary, {:packet, :raw}, {:delay_send, false}] ++ (opts[:socket_options] || [])

    {caller, _} = from
    ref = Process.monitor(caller)

    queue = :queue.in({{:connect, opts}, from, ref}, queue)
    s = %{s | opts: opts, queue: queue}

    case :gen_tcp.connect(host, port, sock_opts, timeout) do
      {:ok, sock} ->
        s = put_in s.sock, {:gen_tcp, sock}
        Protocol.login(%{s | opts: opts, sock: {:gen_tcp, sock}})
      {:error, error} ->
        error(%Tds.Error{message: "tcp connect: #{error}"}, s)
    end
  end

  def handle_call(:attn, from, s) do
    {caller, _} = from
    ref = Process.monitor(caller)
    s = %{s | queue: :queue.new}
    s = update_in s.queue, &:queue.in({:attn, from, ref}, &1)
    case command(:attn, s) do
      {:ok, s} -> {:noreply, s}
      {:error, error, s} -> error(error, s)
    end
  end

  def handle_call(command, from, %{state: state} = s) do
    {caller, _} = from
    ref = Process.monitor(caller)
    s = update_in s.queue, &:queue.in({command, from, ref}, &1)
    case state do
      :ready ->
        case next(s) do
          {:ok, s} -> {:noreply, s}
          {:error, error, s} -> error(error, s)
        end
      _ ->
        {:noreply, s}
    end
  end



  def handle_info({:DOWN, ref, :process, _, _}, s) do
    case :queue.out(s.queue) do
      {{:value, {_,_,^ref}}, _queue} ->
        {_, s} = command(:attn, s)
      {:empty, _} -> nil
      {_, _queue} ->
        queue = s.queue
          |> :queue.to_list
          |> Enum.reject(fn({_, _, r}) -> r == ref end)
          |> :queue.from_list
        s = %{s | queue: queue}
    end
    {:noreply, s}
  end

  def handle_info({:udp, _, _, 1434, <<_head::binary-3, data::binary>>}, %{opts: opts, ireq: pid, usock: sock} = s) do
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
        error(%Tds.Error{message: "Instance #{opts.instance} not found"}, s)
      serv ->
        {port, _} = Integer.parse(serv[:tcp])
        GenServer.reply(pid, :ok)
        {:noreply, %{s | opts: opts, itcp: port}}
    end

  end

  def handle_info({:tcp, _, _data}, %{sock: {mod, sock}, opts: opts, state: :prelogin} = s) do
    case mod do
      :gen_tcp -> :inet.setopts(sock, active: :once)
      :ssl     -> :ssl.setopts(sock, active: :once)
    end
    Protocol.login(%{s | opts: opts, sock: {mod, sock}})
  end

  def handle_info({tag, _, data}, %{sock: {mod, sock}, tail: tail} = s)
      when tag in [:tcp, :ssl] do
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
    error(%Tds.Error{message: "tcp closed"}, s)
  end

  def handle_info({tag, _, reason}, s) when tag in [:tcp_error, :ssl_error] do
    error(%Tds.Error{message: "tcp error: #{reason}"}, s)
  end

  def next(%{queue: queue} = s) do
    case :queue.out(queue) do
      {{:value, {command, _from, _ref}}, _queue} ->
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

  defp command(:attn, s) do
    timeout = s.opts[:timeout] || @timeout
    attn_timer_ref = :erlang.start_timer(timeout, self(), :command)
    Protocol.send_attn(%{s |attn_timer: attn_timer_ref, pak_header: "", pak_data: "", tail: "", state: :attn})
  end

  defp new_data(<<_data::0>>, s) do
    {:ok, s}
  end
  defp new_data(<<0xFD, 0x20, _cur_cmd::binary(2), 0::size(8)-unit(8), _tail::binary>>, %{state: :attn} = s) do
    s = %{s | pak_header: "", pak_data: "", tail: ""}
    Protocol.message(:attn, :attn, s)
  end
  defp new_data(<<_b::size(1)-unit(8), tail::binary>>, %{state: :attn} = s), do: new_data(tail, s)

  defp new_data(<<packet::binary>>, %{state: state, pak_data: buf_data, pak_header: buf_header, tail: tail} = s) do
    <<type::int8, status::int8, size::int16, head_rem::int32, data::binary>> = tail <> packet
    if buf_header == "" do
      buf_header = <<type::int8, status::int8, size::int16, head_rem::int32>>
    else
      data = tail <> packet
    end

    <<type::int8, status::int8, size::int16, _spid::int16, _pack_id::int8, _window::int8>> = buf_header
    size = size - 8

    case data do
      <<data :: binary(size), tail :: binary>> ->
        case status do
          1 ->
            msg = Messages.parse(state, type, buf_header, buf_data<>data)
            case Protocol.message(state, msg, s) do
              {:ok, s} ->
                new_data(tail, %{s | pak_header: "", pak_data: "", tail: tail})
              {:error, _, _} = err ->
                err
            end
          _ ->
            new_data(tail, %{s | pak_data: buf_data <> data, pak_header: "", tail: ""})
        end
      _ ->
        {:ok, %{s | tail: tail <> data, pak_header: buf_header}}
    end
  end

end
