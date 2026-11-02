Code.require_file("support/fake_tds_server.exs", __DIR__)

defmodule ConnectionFailureTest do
  # changes the global log level
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Tds.Encoding.UCS2
  alias Tds.FakeServer

  @closed "tds connection closed (the pool may have closed it after a timeout): :closed"

  setup do
    level = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: level) end)
  end

  defp start_conn(port, opts \\ []) do
    Tds.start_link(
      [
        hostname: "127.0.0.1",
        port: port,
        username: "u",
        password: "p",
        ssl: false,
        execution_mode: :executesql,
        backoff_type: :stop,
        pool_size: 1
      ] ++ opts
    )
  end

  test "a socket closed mid-response returns a disconnect error" do
    partial = FakeServer.packet(0, <<0::size(100)-unit(8)>>)
    {_server, port} = FakeServer.start(script: [{:close, [partial]}])
    {:ok, pid} = start_conn(port)

    log =
      capture_log(fn ->
        assert {:error, %DBConnection.ConnectionError{message: @closed}} =
                 Tds.query(pid, "SELECT 1", [])

        # the pool drops the broken connection
        Process.sleep(100)
      end)

    refute log =~ "bad return value"
  end

  test "a server that stops answering times out" do
    {_server, port} = FakeServer.start(script: [:hang])
    {:ok, pid} = start_conn(port)

    log =
      capture_log(fn ->
        assert {:error, error} = Tds.query(pid, "SELECT 1", [], timeout: 200)
        # DBConnection adds that the pool closed it
        assert %DBConnection.ConnectionError{
                 message: @closed <> " (the connection was closed" <> _
               } =
                 error

        Process.sleep(100)
      end)

    assert log =~ "timed out"
    refute log =~ "bad return value"
  end

  test "a socket closed mid-response raises DBConnection.ConnectionError from query!" do
    partial = FakeServer.packet(0, <<0::size(100)-unit(8)>>)
    {_server, port} = FakeServer.start(script: [{:close, [partial]}])
    {:ok, pid} = start_conn(port)

    capture_log(fn ->
      assert_raise DBConnection.ConnectionError, @closed, fn ->
        Tds.query!(pid, "SELECT 1", [])
      end
    end)
  end

  test "a close after the connection SET batch fails the connect with a ConnectionError" do
    {_server, port} = FakeServer.start(set_batch: :close)

    opts = [hostname: "127.0.0.1", port: port, username: "u", password: "p", ssl: false]
    assert {:error, %DBConnection.ConnectionError{message: @closed}} = Tds.Protocol.connect(opts)
  end

  test "a password login needs no FEDAUTH acknowledgement" do
    {_server, port} = FakeServer.start(fed_auth_ack: false)

    opts = [hostname: "127.0.0.1", port: port, username: "u", password: "p", ssl: false]
    assert {:ok, _state} = Tds.Protocol.connect(opts)
  end

  describe "on a socket the client already closed" do
    setup do
      {_server, port} = FakeServer.start(script: [])

      {:ok, s} =
        Tds.Protocol.connect(
          hostname: "127.0.0.1",
          port: port,
          username: "u",
          password: "p",
          ssl: false
        )

      {:gen_tcp, sock} = s.sock
      :ok = :gen_tcp.close(sock)
      %{state: s}
    end

    test "a send failure returns a ConnectionError disconnect", %{state: s} do
      query = %Tds.Query{statement: "SELECT 1"}

      assert {:disconnect, %DBConnection.ConnectionError{message: @closed}, _s} =
               Tds.Protocol.handle_execute(query, [], [], s)
    end

    test "ping returns a ConnectionError disconnect", %{state: s} do
      assert {:disconnect, %DBConnection.ConnectionError{message: @closed}, _s} =
               Tds.Protocol.ping(s)
    end
  end

  describe "with an access token" do
    @token "SECRET-TOKEN-123"

    defp token_opts(port) do
      [
        hostname: "127.0.0.1",
        port: port,
        ssl: true,
        ssl_opts: [verify: :verify_none],
        access_token: fn -> @token end,
        execution_mode: :executesql,
        backoff_type: :stop,
        pool_size: 1
      ]
    end

    defp refute_token(text) do
      refute text =~ @token
      refute text =~ UCS2.from_string(@token)
    end

    test "LOGIN7 carries the token over TLS and the state never shows it" do
      {_server, port} =
        FakeServer.start(tls: true, script: [{:reply, [FakeServer.packet(1, FakeServer.done())]}])

      log =
        capture_log(fn ->
          assert {:ok, state} = Tds.Protocol.connect(token_opts(port))
          refute_token(inspect(state))
          assert state.access_token == nil
          assert state.opts[:access_token] == :REDACTED
        end)

      # FEDAUTH feature extension with the UTF-16LE token, echo clear
      assert_received {:login7, login7}
      token = UCS2.from_string(@token)

      assert login7 =~
               <<0x02, byte_size(token) + 5::little-32, 0x02, byte_size(token)::little-32>> <>
                 token <> <<0xFF>>

      refute_token(log)
    end

    test "LOGIN7 echoes the server's FEDAUTHREQUIRED" do
      for {required, options} <- [{1, 0x03}, {0, 0x02}] do
        {_server, port} = FakeServer.start(tls: true, fed_auth_required: required)

        capture_log(fn -> assert {:ok, _state} = Tds.Protocol.connect(token_opts(port)) end)

        assert_received {:login7, login7}
        token = UCS2.from_string(@token)

        assert login7 =~
                 <<0x02, byte_size(token) + 5::little-32, options, byte_size(token)::little-32>> <>
                   token
      end
    end

    test "a login the server did not acknowledge as federated fails" do
      {_server, port} = FakeServer.start(tls: true, fed_auth_ack: false)

      capture_log(fn ->
        assert {:error,
                %Tds.Error{message: "server did not acknowledge federated authentication"}} =
                 Tds.Protocol.connect(token_opts(port))
      end)
    end

    test "a redirect sends the token to the routed server" do
      {_target, target_port} = FakeServer.start(tls: true)
      {_gateway, gateway_port} = FakeServer.start(tls: true, redirect: target_port)

      log =
        capture_log(fn ->
          assert {:ok, _state} = Tds.Protocol.connect(token_opts(gateway_port))
        end)

      # one connect, one verify_none warning, although it logs in twice
      assert [_] = Regex.scan(~r/verify: :verify_none/, log)

      token = UCS2.from_string(@token)
      assert_received {:login7, gateway_login7}
      assert_received {:login7, routed_login7}
      assert gateway_login7 =~ token
      assert routed_login7 =~ token
    end

    test "a live connection's state never shows the token or password" do
      {_server, port} = FakeServer.start(tls: true)
      opts = token_opts(port) ++ [password: "pw-123", connection_listeners: [self()]]

      log =
        capture_log(fn ->
          {:ok, _pool} = Tds.start_link(opts)
          assert_receive {:connected, conn}, 5_000

          # DBConnection keeps its start options in its own state, only the
          # driver's part is checked
          {:no_state, %{state: %Tds.Protocol{} = state}} = :sys.get_state(conn)
          inspected = inspect(state, limit: :infinity)
          assert inspected =~ "%Tds.Protocol{"
          refute_token(inspected)
          refute inspected =~ "pw-123"
        end)

      refute_token(log)
    end

    test "a failure mid-login does not show the token" do
      {_server, port} = FakeServer.start(tls: true, login: :close)

      log =
        capture_log(fn ->
          assert {:error, error} = Tds.Protocol.connect(token_opts(port))
          assert %DBConnection.ConnectionError{message: @closed} = error
          refute_token(inspect(error))
        end)

      refute_token(log)
    end

    test "a socket closed mid-query does not show the token" do
      partial = FakeServer.packet(0, <<0::size(100)-unit(8)>>)
      {_server, port} = FakeServer.start(tls: true, script: [{:close, [partial]}])
      {:ok, pid} = Tds.start_link(token_opts(port))

      log =
        capture_log(fn ->
          assert {:error, %DBConnection.ConnectionError{message: @closed}} =
                   Tds.query(pid, "SELECT 1", [])

          Process.sleep(100)
        end)

      refute log =~ "bad return value"
      refute_token(log)
    end

    test "a query timeout does not show the token" do
      {_server, port} = FakeServer.start(tls: true, script: [:hang])
      {:ok, pid} = Tds.start_link(token_opts(port))

      log =
        capture_log(fn ->
          assert {:error, %DBConnection.ConnectionError{}} =
                   Tds.query(pid, "SELECT 1", [], timeout: 200)

          Process.sleep(100)
        end)

      assert log =~ "timed out"
      refute log =~ "bad return value"
      refute_token(log)
    end

    test "inspect never shows credentials" do
      state = %Tds.Protocol{
        opts: [
          password: "pw-123",
          access_token: @token,
          proxy_password: "proxy-123",
          ssl_opts: [
            verify: :verify_peer,
            password: "keyfile-secret",
            key: {:RSAPrivateKey, "der-key-123"},
            certs_keys: [
              %{certfile: "c.pem", key: {:ECPrivateKey, "ec-key-123"}, password: "ck-123"}
            ]
          ]
        ],
        access_token: @token
      }

      inspected = inspect(state)
      refute_token(inspected)
      refute inspected =~ "pw-123"
      refute inspected =~ "proxy-123"

      for secret <- ["keyfile-secret", "der-key-123", "ec-key-123", "ck-123"],
          do: refute(inspected =~ secret)

      assert inspected =~ ":verify_peer"
      assert inspected =~ "c.pem"
      assert inspected =~ "%Tds.Protocol{"
    end
  end
end
