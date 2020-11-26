defmodule Tds.TlsWrapper do
  require Logger

  def send(sock, packet) do
    unless handshake_complete() do
      size = IO.iodata_length(packet) + 8
      Process.put(:handshake_complete, true)
      Logger.debug(
        "SSL_PAYLOAD SIZE: #{size - 8} plus 8 bytes for header in PID #{
          inspect(self())
        }"
      )

      header =
        <<0x12, 0x01, size::unsigned-size(2)-unit(8), 0x00, 0x00, 0x00, 0x00>>

      :gen_tcp.send(sock, [header, packet])
    else
      :gen_tcp.send(sock, packet)
    end
  end

  def recv(sock, length, timeout \\ :infinity) do
    unless handshake_complete() do
      Logger.debug("RECEIVE #{inspect(self())}")

      result = case :gen_tcp.recv(sock, length, timeout) do
        {:ok, <<0x12, 0x01, size::unsigned-16, _::32, tail::binary>>} ->
          remaining = size - 8 + byte_size(tail)

          if remaining == 0,
            do: {:ok, tail},
            else: recv_more(sock, remaining, tail, timeout)

        any ->
          any
      end
      Process.put(:handshake_complete, true)
      result
    else
      :gen_tcp.recv(sock, length, timeout)
    end
  end

  def recv_more(sock, length, payload, timeout) do
    case :gen_tcp.recv(sock, length, timeout) do
      {:ok, tail} ->
        {:ok, [payload, tail] |> IO.iodata_to_binary()}

      any ->
        any
    end
  end

  defp handshake_complete() do
    Process.get(:handshake_complete, false)
  end

  defdelegate getopts(port, options), to: :inet

  defdelegate setopts(socket, options), to: :inet

  defdelegate peername(socket), to: :inet

  :gen_tcp.module_info(:exports)
  |> Enum.reject(fn {fun, _} -> fun in [:send, :recv, :module_info] end)
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
end
