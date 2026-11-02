defmodule LoginRedirectGatewaySocketTest do
  use ExUnit.Case, async: true

  import Tds.Messages

  @moduletag :capture_log

  # When Azure SQL redirects the login, the client must close its connection to
  # the gateway before continuing on the redirect target. Otherwise the gateway
  # closes it later, and with TLS the Tds.Tls process owning that socket stops
  # with :tcp_closed and takes the linked connection process down with it.
  test "the gateway socket is closed when the login is redirected" do
    {:ok, gateway} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, gateway_port} = :inet.port(gateway)
    {:ok, client} = :gen_tcp.connect(~c"127.0.0.1", gateway_port, [:binary, active: false])
    {:ok, server_side} = :gen_tcp.accept(gateway, 1_000)

    # Redirect to a port nobody listens on, so the test needs no SQL Server.
    {:ok, closed} = :gen_tcp.listen(0, [])
    {:ok, closed_port} = :inet.port(closed)
    :ok = :gen_tcp.close(closed)

    state = %Tds.Protocol{
      sock: {:gen_tcp, client},
      opts: [hostname: "127.0.0.1", port: gateway_port, ssl: false, timeout: 1_000]
    }

    redirect = msg_loginack(redirect: %{hostname: "127.0.0.1", port: closed_port})

    Tds.Protocol.message(:login, redirect, state)

    assert {:error, :closed} == :gen_tcp.recv(server_side, 0, 1_000)
    assert Port.info(client) == nil

    :gen_tcp.close(gateway)
  end
end
