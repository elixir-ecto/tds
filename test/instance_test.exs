Code.require_file("support/test_udp.ex", __DIR__)

defmodule Tds.InstanceTest do
  use ExUnit.Case, async: true

  alias Tds.Instance

  test "resolves a named instance with the 3000ms default timeout and closes the socket" do
    response = browser_response("SQLUTF", 51_433)
    Tds.TestUdp.configure(recv: {:ok, {{127, 0, 0, 1}, 1434, response}})

    assert {:ok, 51_433} =
             Instance.resolve(
               hostname: "db.internal",
               instance: "sqlutf",
               instance_udp_module: Tds.TestUdp
             )

    assert_receive {:udp_recv, :test_socket, 0, 3_000}
    assert_receive {:udp_close, :test_socket}
  end

  test "closes the socket and returns an error when sending fails" do
    Tds.TestUdp.configure(send: {:error, :ehostunreach})

    assert {:error, %Tds.Error{message: message}} = resolve()
    assert message =~ "send failed"
    refute_receive {:udp_recv, :test_socket, 0, _timeout}
    assert_receive {:udp_close, :test_socket}
  end

  test "bounds the receive wait with the configured timeout and closes the socket" do
    Tds.TestUdp.configure(recv: {:error, :timeout})

    assert {:error, %Tds.Error{message: message}} = resolve(instance_timeout: 25)
    assert message =~ "timed out after 25ms"
    assert_receive {:udp_recv, :test_socket, 0, 25}
    assert_receive {:udp_close, :test_socket}
  end

  test "converts a raised receive error into Tds.Error and closes the socket" do
    Tds.TestUdp.configure(recv: {:raise, ArgumentError.exception("bad recv")})

    assert {:error, %Tds.Error{message: message}} = resolve()
    assert message =~ "receive failed"
    assert_receive {:udp_close, :test_socket}
  end

  test "rejects a malformed browser response without crashing and closes the socket" do
    malformed = <<5, 0, 0, "InstanceName;SQLUTF;tcp">>
    Tds.TestUdp.configure(recv: {:ok, {{127, 0, 0, 1}, 1434, malformed}})

    assert {:error, %Tds.Error{message: message}} = resolve()
    assert message =~ "malformed response"
    assert_receive {:udp_close, :test_socket}
  end

  test "rejects a valid-looking payload when the declared response length is wrong" do
    <<5, _declared::little-16, data::binary>> = browser_response("SQLUTF", 51_433)
    malformed = <<5, byte_size(data) + 1::little-16, data::binary>>
    Tds.TestUdp.configure(recv: {:ok, {{127, 0, 0, 1}, 1434, malformed}})

    assert {:error, %Tds.Error{message: message}} = resolve()
    assert message =~ "malformed response"
    assert_receive {:udp_close, :test_socket}
  end

  test "returns the configured fixed port when instance lookup fails" do
    Tds.TestUdp.configure(recv: {:error, :timeout})

    assert {:fallback, 15_433, %Tds.Error{message: message}} =
             Instance.resolve_port(
               hostname: "db.internal",
               instance: "SQLUTF",
               port: "15433",
               instance_timeout: 10,
               instance_udp_module: Tds.TestUdp
             )

    assert message =~ "timed out after 10ms"
    assert_receive {:udp_close, :test_socket}
  end

  test "handles an udp open error without attempting send or close" do
    Tds.TestUdp.configure(open: {:error, :eacces})

    assert {:error, %Tds.Error{message: message}} = resolve()
    assert message =~ "udp open failed"
    refute_receive {:udp_send, _socket, _host, _port, _payload}
    refute_receive {:udp_close, _socket}
  end

  test "a real UDP blackhole bounds elapsed time and falls back to the fixed port" do
    {udp_pid, udp_ref, browser_port} = start_udp_blackhole()
    started_at = System.monotonic_time(:millisecond)

    assert {:fallback, 15_433, %Tds.Error{message: message}} =
             Instance.resolve_port(
               hostname: "127.0.0.1",
               instance: "SQLUTF",
               instance_browser_port: browser_port,
               instance_timeout: 30,
               port: 15_433
             )

    elapsed_ms = System.monotonic_time(:millisecond) - started_at

    assert message =~ "timed out after 30ms"
    assert elapsed_ms in 20..1_000
    assert_receive {:udp_query_dropped, ^udp_pid, <<3>>}

    send(udp_pid, :stop)
    assert_receive {:DOWN, ^udp_ref, :process, ^udp_pid, :normal}
  end

  test "Protocol attempts the configured TCP port after a real UDP response loss" do
    {udp_pid, udp_ref, browser_port} = start_udp_blackhole()
    {tcp_pid, tcp_ref, fallback_port} = start_tcp_probe()
    started_at = System.monotonic_time(:millisecond)

    assert {:error, %Tds.Error{}} =
             Tds.Protocol.connect(
               hostname: "127.0.0.1",
               instance: "SQLUTF",
               instance_browser_port: browser_port,
               instance_timeout: 30,
               port: fallback_port,
               username: "test-user",
               password: "test-password",
               timeout: 200
             )

    elapsed_ms = System.monotonic_time(:millisecond) - started_at

    assert elapsed_ms in 20..1_000
    assert_receive {:udp_query_dropped, ^udp_pid, <<3>>}
    assert_receive {:tcp_fallback_connected, ^tcp_pid}
    assert_receive {:DOWN, ^tcp_ref, :process, ^tcp_pid, :normal}

    send(udp_pid, :stop)
    assert_receive {:DOWN, ^udp_ref, :process, ^udp_pid, :normal}
  end

  defp resolve(overrides \\ []) do
    Instance.resolve(
      Keyword.merge(
        [
          hostname: "db.internal",
          instance: "SQLUTF",
          instance_udp_module: Tds.TestUdp
        ],
        overrides
      )
    )
  end

  defp browser_response(instance, port) do
    data =
      "ServerName;DB01;InstanceName;#{instance};IsClustered;No;" <>
        "Version;16.0.1000.6;tcp;#{port};;"

    <<5, byte_size(data)::little-16, data::binary>>
  end

  defp start_udp_blackhole do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        parent_ref = Process.monitor(parent)
        {:ok, socket} = :gen_udp.open(0, [:binary, active: false, reuseaddr: true])
        {:ok, {_address, port}} = :inet.sockname(socket)
        send(parent, {:udp_blackhole_ready, self(), port})

        {:ok, {_peer_address, _peer_port, payload}} = :gen_udp.recv(socket, 0, 1_000)
        send(parent, {:udp_query_dropped, self(), payload})

        receive do
          :stop -> :ok
          {:DOWN, ^parent_ref, :process, ^parent, _reason} -> :ok
        after
          2_000 -> :ok
        end

        :gen_udp.close(socket)
      end)

    assert_receive {:udp_blackhole_ready, ^pid, port}
    {pid, ref, port}
  end

  defp start_tcp_probe do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        {:ok, listener} =
          :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

        {:ok, {_address, port}} = :inet.sockname(listener)
        send(parent, {:tcp_probe_ready, self(), port})

        {:ok, socket} = :gen_tcp.accept(listener, 1_000)
        send(parent, {:tcp_fallback_connected, self()})
        :gen_tcp.close(socket)
        :gen_tcp.close(listener)
      end)

    assert_receive {:tcp_probe_ready, ^pid, port}
    {pid, ref, port}
  end
end
