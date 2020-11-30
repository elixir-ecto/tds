defmodule Tds.Tls do
  @moduledoc false
  require Logger
  use GenServer
  import Kernel, except: [send: 2]

  defstruct [:socket, :ssl_opts, :owner_pid, :handshake]

  def connect(socket, ssl_opts) do
    Logger.debug("starting TLS upgrade")
    ssl_opts = ssl_opts ++ [
      active: false,
      log_level: :debug,
      log_alert: true,
      handshake: :full,
      cb_info: {Tds.Tls, :tcp, :tcp_closed, :tcp_error, :tcp_passive}
    ]
    :inet.setopts(socket, active: false)
    with {:ok, pid} <- GenServer.start_link(__MODULE__, {socket, ssl_opts}, []),
         :ok <- :gen_tcp.controlling_process(socket, pid) do
      res = :ssl.connect(socket, ssl_opts, :infinity)
      GenServer.cast(pid, :handshake_complete)
      res
    else
      error -> error
    end
  end

  def controlling_process(socket, tls_conn_pid) do
    {:connected, pid} = Port.info(socket, :connected)
    GenServer.call(pid, {:controlling_process, tls_conn_pid})
  end

  def send(socket, payload) do
    {:connected, pid} = Port.info(socket, :connected)
    GenServer.call(pid, {:send, payload})
  end

  def recv(socket, length, timeout \\ :infinity) do
    {:connected, pid} = Port.info(socket, :connected)
    GenServer.call(pid, {:recv, length, timeout}, timeout)
  end

  defdelegate getopts(port, options), to: :inet

  # defdelegate setopts(socket, options), to: :inet
  def setopts(socket, options) do
    {:connected, pid} = Port.info(socket, :connected)
    GenServer.call(pid, {:setopts, options})
  end

  defdelegate peername(socket), to: :inet

  :exports
  |> :gen_tcp.module_info()
  |> Enum.reject(fn {fun, _} ->
    fun in [:send, :recv, :module_info, :controlling_process]
  end)
  |> Enum.each(fn
    {name, 0} ->
      defdelegate unquote(name)(), to: :gen_tcp

    {name, 1} ->
      defdelegate unquote(name)(arg1), to: :gen_tcp

    {name, 2} ->
      defdelegate unquote(name)(arg1, arg2), to: :gen_tcp

    {name, 3} ->
      defdelegate unquote(name)(arg1, arg2, arg3), to: :gen_tcp

    {name, 4} ->
      defdelegate unquote(name)(arg1, arg2, arg3, arg4), to: :gen_tcp
  end)

  # SERVER
  def init({socket, ssl_opts}) do
    {:ok, %__MODULE__{socket: socket, ssl_opts: ssl_opts, handshake: true}}
  end

  def handle_call({:controlling_process, tls_conn_pid}, _from, s) do
    {:reply, :ok, %{s | owner_pid: tls_conn_pid}}
  end

  def handle_call({:setopts, options}, _from, %{socket: socket, handshake: hs} = s) do
    tds_header_size = if hs == true, do: 8, else: 0

    opts =
      options
      |> Enum.map(fn
        {:active, val} when is_number(val) -> {:active, val + tds_header_size}
        val -> val
      end)

    {:reply, :inet.setopts(socket, opts), s}
  end

  def handle_call({:send, data}, _from, %{socket: socket, handshake: true} = s) do
    size = IO.iodata_length(data) + 8
    header =
      <<0x12, 0x01, size::unsigned-size(2)-unit(8), 0x00, 0x00, 0x00, 0x00>>

    resp = :gen_tcp.send(socket, [header, data])
    {:reply, resp, s}
  end

  def handle_call({:send, data}, _from,  %{socket: socket, handshake: false} = s) do
    resp = :gen_tcp.send(socket, data)
    {:reply, resp, s}
  end

  # def handle_call({:recv, length, timeout}, _from, %{socket: socket, handshake: true} = s) do
  #   res = case :gen_tcp.recv(socket, length, timeout) do
  #     {:ok, data}
  #   end
  #   {:reply, res, s}
  # end

  def handle_call({:recv, length, timeout}, _from, %{socket: socket} = s) do
    res = :gen_tcp.recv(socket, length, timeout)
    {:reply, res, s}
  end

  def handle_cast(:handshake_complete, s) do
    {:noreply, %{s | handshake: false} }
  end

  def handle_info(
        {:tcp, _,
         <<0x12, 0x01, size::unsigned-16, _::32, ssl_payload::binary>>},
        %{socket: socket, owner_pid: pid} = s
      ) do
    Logger.debug(
      "received #{size} bytes from server in prelogin message as SSL_PAYLOAD"
    )

    Kernel.send(pid, {:tcp, socket, ssl_payload})
    {:noreply, s}
  end

  def handle_info({:tcp, _, _} = msg, %{owner_pid: pid} = s) do
    Logger.debug("received SSL_PAYLOAD from server, NON PreLogin message")

    Kernel.send(pid, msg)
    {:noreply, s}
  end

  def handle_info({tag, _} = msg, %{owner_pid: pid} = s)
      when tag in [:tcp_closed, :ssl_closed] do
    # todo
    send(pid, msg)
    {:stop, tag, s}
  end

  def handle_info({tag, _, _} = msg, %{owner_pid: pid} = s)
      when tag in [:tcp_error, :ssl_error] do
    # todo
    send(pid, msg)
    {:stop, tag, s}
  end
end
