defmodule FedAuthTest do
  use ExUnit.Case, async: true

  import Tds.Messages, only: [msg_loginack: 1]

  alias Tds.Encoding.UCS2
  alias Tds.Messages
  alias Tds.Protocol.{Login7, Prelogin}

  @login_opts [hostname: "db.example.net", username: "sa", password: "pw", database: "app"]
  @token "eyJhbGciOi.secret-access-token.c2lnbmF0dXJl"

  # Fixes the two fields `Login7.new/2` reads from the host.
  defp login7_bytes(opts, fed_auth \\ %{echo: false, nonce: nil}) do
    login = %{Login7.new(opts, fed_auth) | hostname: "client", client_pid: <<0, 0, 3, 34>>}
    login |> Login7.encode() |> IO.iodata_to_binary()
  end

  defp prelogin_bytes(opts) do
    opts |> Prelogin.encode() |> IO.iodata_to_binary()
  end

  # Prelogin's THREADID option carries the calling process's pid serial.
  defp thread_id do
    [_, serial, _] = self() |> inspect() |> String.split(".")
    <<String.to_integer(serial)::unsigned-32>>
  end

  defp version do
    [major, minor, build] =
      Mix.Project.config()[:version] |> String.split(".") |> Enum.map(&String.to_integer/1)

    <<build::little-unsigned-16, minor, major, 0, 0>>
  end

  defp expected_prelogin do
    <<0x12, 0x01, 0x00, 0x2F, 0x00, 0x00, 0x01, 0x00>> <>
      <<0x00, 0x00, 0x1A, 0x00, 0x06>> <>
      <<0x01, 0x00, 0x20, 0x00, 0x01>> <>
      <<0x03, 0x00, 0x21, 0x00, 0x04>> <>
      <<0x04, 0x00, 0x25, 0x00, 0x01>> <>
      <<0x06, 0x00, 0x26, 0x00, 0x01>> <>
      <<0xFF>> <>
      version() <> <<0x03>> <> thread_id() <> <<0x00>> <> <<0x01>>
  end

  describe "PRELOGIN golden bytes" do
    test "SQL authentication requests encryption and advertises FEDAUTHREQUIRED" do
      assert prelogin_bytes(ssl: true) == expected_prelogin()
    end

    test "an access token does not change the PRELOGIN packet" do
      assert prelogin_bytes(ssl: true, access_token: "tkn") == expected_prelogin()
    end
  end

  describe "LOGIN7 golden bytes" do
    test "SQL authentication is unchanged: credentials set, no FeatureExt" do
      assert login7_bytes(@login_opts) ==
               <<16, 1, 0, 184, 0, 0, 1, 0, 176, 0, 0, 0, 4, 0, 0, 116, 0, 16, 0, 0, 4, 0, 0, 7,
                 0, 0, 3, 34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 4, 0, 0, 94, 0, 6, 0, 106, 0,
                 2, 0, 110, 0, 2, 0, 114, 0, 10, 0, 134, 0, 14, 0, 0, 0, 0, 0, 162, 0, 4, 0, 0, 0,
                 0, 0, 170, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 99, 0, 108, 0, 105, 0, 101, 0, 110, 0, 116, 0, 115, 0, 97, 0, 162, 165,
                 210, 165, 69, 0, 108, 0, 105, 0, 120, 0, 105, 0, 114, 0, 32, 0, 84, 0, 68, 0, 83,
                 0, 100, 0, 98, 0, 46, 0, 101, 0, 120, 0, 97, 0, 109, 0, 112, 0, 108, 0, 101, 0,
                 46, 0, 110, 0, 101, 0, 116, 0, 79, 0, 68, 0, 66, 0, 67, 0, 97, 0, 112, 0, 112,
                 0>>
    end

    test "an access token sends empty credentials, fExtension and a FEDAUTH SECURITYTOKEN feature" do
      bytes = login7_bytes(@login_opts ++ [access_token: "tkn"], %{echo: true, nonce: nil})

      # packet header (LOGIN7, EOM, 197 bytes), then Length 189
      header = <<0x10, 0x01, 0x00, 0xC5, 0x00, 0x00, 0x01, 0x00, 189, 0, 0, 0>>
      # TDSVersion, PacketSize, ClientProgVer, ClientPID, ConnectionID
      fixed = <<4, 0, 0, 116, 0, 16, 0, 0, 4, 0, 0, 7, 0, 0, 3, 34, 0, 0, 0, 0>>

      # OptionFlags1, OptionFlags2, TypeFlags, OptionFlags3 (fExtension), ClientTimeZone, ClientLCID
      flags = <<0x00, 0x00, 0x00, 0x10, 0, 0, 0, 0, 9, 4, 0, 0>>
      # HostName 94/6, UserName 106/0, Password 106/0, AppName 106/10, ServerName 126/14
      names = <<94, 0, 6, 0, 106, 0, 0, 0, 106, 0, 0, 0, 106, 0, 10, 0, 126, 0, 14, 0>>
      # ibExtension 168/4, CltIntName 154/4, Language, Database 162/3
      more = <<168, 0, 4, 0, 154, 0, 4, 0, 0, 0, 0, 0, 162, 0, 3, 0>>
      # ClientID, SSPI, AtchDBFile, ChangePassword, cbSSPILong
      rest = :binary.copy(<<0>>, 22)

      data =
        Enum.map_join(
          ["client", "Elixir TDS", "db.example.net", "ODBC", "app"],
          &UCS2.from_string/1
        )

      # Extension DWORD: the FeatureExt block starts at offset 172
      extension = <<172, 0, 0, 0>>
      # FEDAUTH, FeatureDataLen 11, bOptions (SECURITYTOKEN << 1 | fFedAuthEcho),
      # FedAuthToken (DWORD length, UTF-16LE "tkn"), terminator
      feature_ext = <<0x02, 11, 0, 0, 0, 0x03, 6, 0, 0, 0, 116, 0, 107, 0, 110, 0, 0xFF>>

      assert bytes ==
               header <>
                 fixed <> flags <> names <> more <> rest <> data <> extension <> feature_ext
    end

    test "fFedAuthEcho is clear when the server did not answer FEDAUTHREQUIRED" do
      bytes = login7_bytes(@login_opts ++ [access_token: "tkn"])
      assert binary_part(bytes, byte_size(bytes) - 12, 1) == <<0x02>>
    end

    test "an empty database is sent as an empty field, not read past the FeatureExt" do
      bytes = login7_bytes(Keyword.put(@login_opts, :database, "") ++ [access_token: "tkn"])

      <<_::binary-size(8 + 4 + 64), ib_database::little-16, cch_database::little-16, _::binary>> =
        bytes

      assert cch_database == 0
      <<_::binary-size(8 + ib_database), feature_ext_at::little-32, _::binary>> = bytes
      assert <<_::binary-size(8 + feature_ext_at), 0x02, _::binary>> = bytes
    end

    test "a token larger than one packet spans several LOGIN7 packets" do
      token = String.duplicate("a", 4096)
      packets = Login7.encode(%{Login7.new(@login_opts ++ [access_token: token]) | hostname: "c"})

      assert length(packets) == 3

      body =
        Enum.map_join(packets, fn p ->
          binary_part(IO.iodata_to_binary(p), 8, byte_size(IO.iodata_to_binary(p)) - 8)
        end)

      assert :binary.match(body, <<byte_size(token) * 2::little-32>> <> UCS2.from_string(token)) !=
               :nomatch
    end

    test "echoes the server's PRELOGIN nonce after the token" do
      nonce = :binary.copy(<<0xAB>>, 32)
      bytes = login7_bytes(@login_opts ++ [access_token: "tkn"], %{echo: false, nonce: nonce})

      assert binary_part(bytes, byte_size(bytes) - 49, 49) ==
               <<0x02, 43::little-32, 0x02, 6::little-32, 116, 0, 107, 0, 110, 0>> <>
                 nonce <> <<0xFF>>
    end
  end

  describe "PRELOGIN response" do
    # VERSION, ENCRYPTION and FEDAUTHREQUIRED options, as a server sends them.
    defp prelogin_response(encryption, fed_auth_required) do
      <<0x00, 0x00, 0x10, 0x00, 0x06, 0x01, 0x00, 0x16, 0x00, 0x01, 0x06, 0x00, 0x17, 0x00, 0x01,
        0xFF, 16, 0, 0x0F, 0xA0, 0, 0, encryption, fed_auth_required>>
    end

    test "records the server's FEDAUTHREQUIRED answer for LOGIN7 to echo" do
      s = %Tds.Protocol{opts: [ssl: true, access_token: "tkn"]}

      assert {:encrypt, %{fed_auth: %{echo: true}}} =
               Prelogin.decode(prelogin_response(0x01, 0x01), s)

      assert {:encrypt, %{fed_auth: %{echo: false}}} =
               Prelogin.decode(prelogin_response(0x01, 0x00), s)
    end

    test "records a server NONCE for LOGIN7 to echo" do
      nonce = :binary.copy(<<0xCD>>, 32)

      response =
        <<0x01, 0x00, 0x0B, 0x00, 0x01, 0x07, 0x00, 0x0C, 0x00, 0x20, 0xFF, 0x01>> <> nonce

      s = %Tds.Protocol{opts: [ssl: true, access_token: "tkn"]}
      assert {:encrypt, %{fed_auth: %{nonce: ^nonce}}} = Prelogin.decode(response, s)
    end
  end

  describe "connecting with an access token" do
    # Port 1 refuses connections, so an error naming the token proves no socket was opened.
    @conn [hostname: "127.0.0.1", port: 1, database: "app"]

    test "is refused without encryption, before LOGIN7 is sent" do
      for ssl <- [false, :not_supported] do
        assert {:error, %Tds.Error{message: message}} =
                 Tds.Protocol.connect(@conn ++ [ssl: ssl, access_token: "tkn"])

        assert message =~ "requires an encrypted connection"
        refute message =~ "tkn"
      end
    end

    test "is refused alongside a password" do
      assert {:error, %Tds.Error{message: message}} =
               Tds.Protocol.connect(@conn ++ [ssl: true, password: "pw", access_token: "tkn"])

      assert message =~ "not both"
    end

    test "is refused when it is not UTF-8, without echoing it" do
      assert {:error, %Tds.Error{message: message}} =
               Tds.Protocol.connect(@conn ++ [ssl: true, access_token: <<0xFF, 0xFE>>])

      assert message =~ "UTF-8"
      refute message =~ <<0xFF>>
    end

    test "nil means SQL authentication" do
      assert {:error, %Tds.Error{message: "tcp connect: econnrefused"}} =
               Tds.Protocol.connect(@conn ++ [access_token: nil])
    end

    test "is refused when the token is empty" do
      assert {:error, %Tds.Error{message: message}} =
               Tds.Protocol.connect(@conn ++ [ssl: true, access_token: ""])

      assert message =~ "non-empty"
    end
  end

  describe "FEATUREEXTACK" do
    @featureextack <<0xAE, 0x02, 0, 0, 0, 0, 0xFF>>
    @loginack <<0xAD, 28::little-16, 1, 0x74, 0, 0, 4, 9>> <>
                UCS2.from_string("SQLServer") <> <<16, 0, 0x10, 0x34>>
    @done <<0xFD, 0::little-16, 0::little-16, 0::little-64>>

    test "decodes a FEATUREEXTACK followed by a LOGINACK" do
      assert [
               {:featureextack, %{0x02 => ""}},
               {:loginack, %{program: "SQLServer", version: "16.0.16.52"}},
               {:done, _}
             ] = Tds.Tokens.decode_tokens(@featureextack <> @loginack <> @done)
    end

    test "decodes a LOGINACK followed by a FEATUREEXTACK, as servers send them" do
      assert [{:loginack, _}, {:featureextack, %{0x02 => ""}}, {:done, _}] =
               Tds.Tokens.decode_tokens(@loginack <> @featureextack <> @done)
    end

    test "carries each feature's acknowledgement data" do
      ack = <<0xAE, 0x02, 2, 0, 0, 0, 0xAB, 0xCD, 0x0A, 1, 0, 0, 0, 0x01, 0xFF>>

      assert [{:featureextack, %{0x02 => <<0xAB, 0xCD>>, 0x0A => <<0x01>>}}] =
               Tds.Tokens.decode_tokens(ack)
    end

    test "a login response carrying one is a login acknowledgement" do
      s = %Tds.Protocol{opts: [access_token: "tkn"]}

      assert {msg_loginack(redirect: nil), _} =
               Messages.parse(:login, @loginack <> @featureextack <> @done, s)
    end
  end

  describe "the access token stays out of errors and state" do
    defp login_failed do
      text = UCS2.from_string("Login failed for user '<token-identified principal>'.")
      server = UCS2.from_string("db")

      data =
        <<18456::little-32, 1, 14, div(byte_size(text), 2)::little-16>> <>
          text <> <<div(byte_size(server), 2)>> <> server <> <<0, 1::little-32>>

      <<0xAA, byte_size(data)::little-16>> <> data <> @done
    end

    test "a login refusal is a Tds.Error without the token" do
      s = %Tds.Protocol{opts: [hostname: "db", access_token: @token], state: :login}
      {msg, s} = Messages.parse(:login, login_failed(), s)

      assert {:error, %Tds.Error{} = error, state} = Tds.Protocol.message(:login, msg, s)
      assert Exception.message(error) =~ "Login failed"
      refute Exception.message(error) =~ @token
      refute inspect(error) =~ @token
      refute inspect(state) =~ @token
    end

    test "inspecting connection state redacts the token and the password" do
      s = %Tds.Protocol{opts: [hostname: "db", password: "hunter2", access_token: @token]}

      refute inspect(s) =~ @token
      refute inspect(s) =~ "hunter2"
      assert inspect(s) =~ "hostname"
      assert s.opts[:access_token] == @token
    end

    test "inspecting a LOGIN7 message redacts the token and the password" do
      login = Login7.new(@login_opts ++ [access_token: @token])
      refute inspect(login) =~ @token

      refute inspect(Login7.new(@login_opts)) =~ ~s(password: "pw")
    end
  end

  describe "logging in over a connection" do
    @conn_opts [hostname: "db", database: "app", ssl: true, access_token: @token]

    defp listen do
      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false])
      {:ok, port} = :inet.port(listen)
      {listen, port}
    end

    # Accepts one connection, forwards each client message to the test, and
    # answers it with the next of `responses`.
    defp fake_server(responses) do
      {listen, port} = listen()
      test = self()

      spawn_link(fn ->
        {:ok, sock} = :gen_tcp.accept(listen)

        for response <- responses do
          send(test, {:client_sent, port, recv_message(sock)})
          :ok = :gen_tcp.send(sock, Messages.encode_packets(0x04, response))
        end
      end)

      port
    end

    defp recv_message(sock, acc \\ <<>>) do
      {:ok, <<_type, status, length::16, _::32>>} = :gen_tcp.recv(sock, 8)
      {:ok, body} = :gen_tcp.recv(sock, length - 8)

      if Bitwise.band(status, 0x01) == 0x01,
        do: acc <> body,
        else: recv_message(sock, acc <> body)
    end

    defp prelogged_in(port, fed_auth_required, opts \\ @conn_opts) do
      {:ok, sock} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])
      s = %Tds.Protocol{sock: {:gen_tcp, sock}, opts: opts}
      {:encrypt, s} = Prelogin.decode(prelogin_response(0x01, fed_auth_required), s)
      s
    end

    defp fedauth_feature(echo) do
      token = UCS2.from_string(@token)

      <<0x02, 1 + 4 + byte_size(token)::little-32, 0x02 + echo, byte_size(token)::little-32>> <>
        token
    end

    for {answer, echo} <- [{0x01, 1}, {0x00, 0}] do
      test "LOGIN7 echoes FEDAUTHREQUIRED #{answer} as fFedAuthEcho #{echo} and the token is redacted once logged in" do
        port = fake_server([@loginack <> @featureextack <> @done, @done])

        assert {:ok, s} = port |> prelogged_in(unquote(answer)) |> Tds.Protocol.login()
        assert_received {:client_sent, ^port, login7}
        assert :binary.match(login7, fedauth_feature(unquote(echo))) != :nomatch
        assert s.opts[:access_token] == :REDACTED
      end
    end

    test "a LOGINACK without a FEDAUTH acknowledgement fails the login" do
      port = fake_server([@loginack <> @done])

      assert {:error, %Tds.Error{message: message}, s} =
               port |> prelogged_in(0x01) |> Tds.Protocol.login()

      assert message =~ "did not acknowledge"
      refute inspect(s) =~ @token
    end

    # The state's options carry an environment-default password by then, which
    # `connect/1` would refuse alongside the token.
    test "a routing redirect reconnects with the token to the named server" do
      {listen, target} = listen()
      host = UCS2.from_string("127.0.0.1")

      routing =
        <<0x00, target::little-16, div(byte_size(host), 2)::little-16>> <> host <> <<0, 0>>

      envchange =
        <<0xE3, byte_size(routing) + 3::little-16, 0x14, byte_size(routing)::little-16>> <>
          routing

      port = fake_server([envchange <> @loginack <> @featureextack <> @done])
      s = prelogged_in(port, 0x01, @conn_opts ++ [password: "from-env"])
      test = self()

      spawn_link(fn ->
        {:ok, sock} = :gen_tcp.accept(listen)
        send(test, {:prelogin, recv_message(sock)})
      end)

      assert {:error, %Tds.Error{} = error, _} = Tds.Protocol.login(s)
      assert_receive {:prelogin, <<0x00, _::binary>>}
      refute inspect(error) =~ @token
    end
  end
end
