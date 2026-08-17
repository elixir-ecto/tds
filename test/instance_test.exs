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
end
