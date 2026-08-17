defmodule Tds.TestUdp do
  @moduledoc false

  @config_key {__MODULE__, :config}

  def configure(config), do: Process.put(@config_key, config)

  def open(port, options) do
    send(self(), {:udp_open, port, options})
    response(:open, {:ok, :test_socket})
  end

  def send(socket, host, port, payload) do
    send(self(), {:udp_send, socket, host, port, payload})
    response(:send, :ok)
  end

  def recv(socket, length, timeout) do
    send(self(), {:udp_recv, socket, length, timeout})
    response(:recv, {:error, :timeout})
  end

  def close(socket) do
    send(self(), {:udp_close, socket})
    response(:close, :ok)
  end

  defp response(key, default) do
    case Keyword.get(Process.get(@config_key, []), key, default) do
      {:raise, exception} -> raise exception
      {:throw, reason} -> throw(reason)
      response -> response
    end
  end
end
