Code.require_file("support/fake_tds_server.exs", __DIR__)

defmodule TlsLifecycleTest do
  use ExUnit.Case, async: false

  alias Tds.FakeServer

  @moduletag :capture_log

  defp ok_reply, do: {:reply, [FakeServer.packet(1, FakeServer.done())]}

  defp tls_opts(port) do
    [
      hostname: "127.0.0.1",
      port: port,
      username: "u",
      password: "p",
      ssl: true,
      ssl_opts: [verify: :verify_none],
      execution_mode: :executesql,
      pool_size: 1
    ]
  end

  # The Tds.Tls transport the calling process started for its connection
  defp tls_transport do
    {:links, links} = Process.info(self(), :links)

    Enum.find(links, fn pid ->
      is_pid(pid) and match?({Tds.Tls, :init, _}, :proc_lib.translate_initial_call(pid))
    end)
  end

  test "a server close mid-query disconnects and the same connection process reconnects" do
    partial = FakeServer.packet(0, <<0::size(100)-unit(8)>>)

    {_server, port} =
      FakeServer.start([
        [tls: true, script: [{:close, [partial]}]],
        [tls: true, script: [ok_reply()]]
      ])

    opts = tls_opts(port) ++ [connection_listeners: [self()], backoff_min: 10, backoff_max: 50]
    {:ok, pool} = Tds.start_link(opts)
    assert_receive {:connected, conn}, 5_000
    ref = Process.monitor(conn)

    assert {:error, _} = Tds.query(pool, "SELECT 1", [])
    assert_receive {:disconnected, ^conn}, 5_000
    assert_receive {:connected, ^conn}, 5_000
    refute_received {:DOWN, ^ref, _, _, _}

    assert {:ok, %Tds.Result{num_rows: 5}} = Tds.query(pool, "SELECT 1", [])
    assert Process.alive?(conn)
  end

  test "disconnect stops the TLS transport" do
    {_server, port} = FakeServer.start(tls: true)
    {:ok, state} = Tds.Protocol.connect(tls_opts(port))
    tls = tls_transport()
    assert is_pid(tls)
    ref = Process.monitor(tls)

    Tds.Protocol.disconnect(RuntimeError.exception("bye"), state)
    assert_receive {:DOWN, ^ref, :process, ^tls, :normal}, 1_000
  end

  test "max_response_bytes closing the connection stops the TLS transport" do
    junk = FakeServer.packet(0, <<0::size(4000)-unit(8)>>)
    {_server, port} = FakeServer.start(tls: true, script: [{:reply, [junk, junk]}])
    {:ok, state} = Tds.Protocol.connect(tls_opts(port) ++ [max_response_bytes: 6_000])
    tls = tls_transport()
    ref = Process.monitor(tls)

    assert {:disconnect, %Tds.ResponseTooLargeError{}, _} =
             Tds.Protocol.handle_execute(%Tds.Query{statement: "SELECT 1"}, [], [], state)

    assert_receive {:DOWN, ^ref, :process, ^tls, :normal}, 1_000
  end

  test "a redirect closes the gateway leg and the routed connection outlives it" do
    {_target, target_port} = FakeServer.start(tls: true, script: [ok_reply(), ok_reply()])
    {_gateway, gateway_port} = FakeServer.start(tls: true, redirect: target_port)

    opts = tls_opts(gateway_port) ++ [connection_listeners: [self()], backoff_type: :stop]
    {:ok, pool} = Tds.start_link(opts)
    assert_receive {:connected, conn}, 5_000
    ref = Process.monitor(conn)

    assert {:ok, %Tds.Result{num_rows: 5}} = Tds.query(pool, "SELECT 1", [])

    # the client hangs up on the gateway rather than leaving the leg open
    assert_receive {:gateway_leg, {:error, :closed}}, 1_000
    Process.sleep(100)

    assert {:ok, %Tds.Result{num_rows: 5}} = Tds.query(pool, "SELECT 1", [])
    refute_received {:disconnected, _}
    refute_received {:DOWN, ^ref, _, _, _}
  end

  test "a redirect sends the routed host as SNI" do
    {_target, target_port} = FakeServer.start(tls: true)

    {_gateway, gateway_port} =
      FakeServer.start(tls: true, redirect: target_port, route_host: "localhost")

    ssl_opts = [verify: :verify_none, server_name_indication: ~c"gateway.example"]
    opts = Keyword.put(tls_opts(gateway_port), :ssl_opts, ssl_opts)

    assert {:ok, _state} = Tds.Protocol.connect(opts)
    assert_received {:sni, ~c"gateway.example"}
    assert_received {:sni, ~c"localhost"}
  end

  test "failed TLS logins leave no ssl or TLS transport processes behind" do
    parent = self()

    client =
      spawn(fn ->
        for _ <- 1..5 do
          {_server, port} = FakeServer.start(tls: true, fed_auth_ack: false)
          opts = tls_opts(port) ++ [access_token: "tok"]
          {:error, _} = Tds.Protocol.connect(opts)
        end

        send(parent, {:done, Process.info(self(), :links)})
        Process.sleep(:infinity)
      end)

    assert_receive {:done, {:links, links}}, 10_000
    Process.sleep(200)

    # each ssl connection process monitors its owner
    assert {:monitored_by, []} = Process.info(client, :monitored_by)
    assert Enum.filter(links, &(is_pid(&1) and Process.alive?(&1))) == []
    Process.exit(client, :kill)
  end

  describe "Tds.Tls on a socket event" do
    setup do
      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false])
      {:ok, port} = :inet.port(listen)
      {:ok, sock} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])
      {:ok, tls} = GenServer.start(Tds.Tls, {sock, []})
      :ok = GenServer.call(tls, {:controlling_process, self()})
      %{sock: sock, tls: tls, ref: Process.monitor(tls)}
    end

    for event <- [:tcp_closed, :ssl_closed] do
      test "#{event} is passed on and stops it normally", %{sock: sock, tls: tls, ref: ref} do
        send(tls, {unquote(event), sock})

        assert_receive {unquote(event), ^sock}
        assert_receive {:DOWN, ^ref, :process, ^tls, :normal}
      end
    end

    for event <- [:tcp_error, :ssl_error] do
      test "#{event} is passed on and stops it normally", %{sock: sock, tls: tls, ref: ref} do
        send(tls, {unquote(event), sock, :econnreset})

        assert_receive {unquote(event), ^sock, :econnreset}
        assert_receive {:DOWN, ^ref, :process, ^tls, :normal}
      end
    end
  end
end
