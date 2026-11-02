defmodule Login7Test do
  use ExUnit.Case, async: true

  alias Tds.Protocol.Login7

  test "encode login7 message" do
    login = %Tds.Protocol.Login7{
      app_name: "Elixir TDS",
      client_language_code_id: <<9, 4, 0, 0>>,
      client_pid: <<0, 0, 3, 34>>,
      client_time_zone: <<0, 0, 0, 0>>,
      client_version: <<4, 0, 0, 7>>,
      connection_id: <<0, 0, 0, 0>>,
      database: "my_database",
      hostname: "test.host.com",
      option_flags_1: <<0>>,
      option_flags_2: <<0>>,
      option_flags_3: <<0>>,
      packet_size: <<0, 16, 0, 0>>,
      password: "password",
      servername: "some.host.com",
      tds_version: <<4, 0, 0, 116>>,
      type_flags: <<0>>,
      username: "test"
    }

    assert Login7.encode(login) ==
             [
               <<16, 1, 0, 228, 0, 0, 1, 0, 220, 0, 0, 0, 4, 0, 0, 116, 0, 16, 0, 0, 4, 0, 0, 7,
                 0, 0, 3, 34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 4, 0, 0, 94, 0, 13, 0, 120,
                 0, 4, 0, 128, 0, 8, 0, 144, 0, 10, 0, 164, 0, 13, 0, 0, 0, 0, 0, 190, 0, 4, 0, 0,
                 0, 0, 0, 198, 0, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 116, 0, 101, 0, 115, 0, 116, 0, 46, 0, 104, 0, 111, 0, 115, 0, 116, 0,
                 46, 0, 99, 0, 111, 0, 109, 0, 116, 0, 101, 0, 115, 0, 116, 0, 162, 165, 179, 165,
                 146, 165, 146, 165, 210, 165, 83, 165, 130, 165, 227, 165, 69, 0, 108, 0, 105, 0,
                 120, 0, 105, 0, 114, 0, 32, 0, 84, 0, 68, 0, 83, 0, 115, 0, 111, 0, 109, 0, 101,
                 0, 46, 0, 104, 0, 111, 0, 115, 0, 116, 0, 46, 0, 99, 0, 111, 0, 109, 0, 79, 0,
                 68, 0, 66, 0, 67, 0, 109, 0, 121, 0, 95, 0, 100, 0, 97, 0, 116, 0, 97, 0, 98, 0,
                 97, 0, 115, 0, 101, 0>>
             ]
  end

  describe "federated authentication with an access token" do
    @fed_auth_login %Tds.Protocol.Login7{
      app_name: "Elixir TDS",
      client_language_code_id: <<9, 4, 0, 0>>,
      client_pid: <<0, 0, 3, 34>>,
      client_time_zone: <<0, 0, 0, 0>>,
      client_version: <<4, 0, 0, 7>>,
      connection_id: <<0, 0, 0, 0>>,
      database: "my_database",
      hostname: "test.host.com",
      option_flags_1: <<0>>,
      option_flags_2: <<0>>,
      option_flags_3: <<0x10>>,
      packet_size: <<0, 16, 0, 0>>,
      password: "",
      servername: "some.host.com",
      tds_version: <<4, 0, 0, 116>>,
      type_flags: <<0>>,
      username: "",
      fed_auth: %{token: "abc", echo: true}
    }

    test "new/1 without :access_token keeps SQL Server authentication" do
      login = Login7.new(hostname: "h", username: "u", password: "p", fed_auth_echo: true)

      assert login.fed_auth == nil
      assert login.option_flags_3 == <<0>>
      assert {login.username, login.password} == {"u", "p"}
    end

    test "new/1 with :access_token sets fExtension and blanks the credentials" do
      login =
        Login7.new(
          hostname: "h",
          username: "u",
          password: "p",
          access_token: "tok",
          fed_auth_echo: true
        )

      assert login.fed_auth == %{token: "tok", echo: true}
      assert login.option_flags_3 == <<0x10>>
      assert {login.username, login.password} == {"", ""}
    end

    test "encodes the FEDAUTH feature extension after the variable data" do
      # ibExtension (196, cbExtension 4) points to a DWORD holding 200, the
      # offset of the FeatureExt block: FeatureId 0x02, FeatureDataLen 11,
      # options 0x03 (SecurityToken << 1 | fFedAuthEcho), token length 6,
      # "abc" as UTF-16LE, terminator 0xFF
      assert Login7.encode(@fed_auth_login) ==
               [
                 <<16, 1, 0, 225, 0, 0, 1, 0, 217, 0, 0, 0, 4, 0, 0, 116, 0, 16, 0, 0, 4, 0, 0, 7,
                   0, 0, 3, 34, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 9, 4, 0, 0, 94, 0, 13, 0,
                   120, 0, 0, 0, 120, 0, 0, 0, 120, 0, 10, 0, 140, 0, 13, 0, 196, 0, 4, 0, 166, 0,
                   4, 0, 0, 0, 0, 0, 174, 0, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   0, 0, 0, 0, 0, 0, 0, 116, 0, 101, 0, 115, 0, 116, 0, 46, 0, 104, 0, 111, 0,
                   115, 0, 116, 0, 46, 0, 99, 0, 111, 0, 109, 0, 69, 0, 108, 0, 105, 0, 120, 0,
                   105, 0, 114, 0, 32, 0, 84, 0, 68, 0, 83, 0, 115, 0, 111, 0, 109, 0, 101, 0, 46,
                   0, 104, 0, 111, 0, 115, 0, 116, 0, 46, 0, 99, 0, 111, 0, 109, 0, 79, 0, 68, 0,
                   66, 0, 67, 0, 109, 0, 121, 0, 95, 0, 100, 0, 97, 0, 116, 0, 97, 0, 98, 0, 97,
                   0, 115, 0, 101, 0, 200, 0, 0, 0, 2, 11, 0, 0, 0, 3, 6, 0, 0, 0, 97, 0, 98, 0,
                   99, 0, 255>>
               ]
    end

    test "fFedAuthEcho is clear when the server did not send FEDAUTHREQUIRED" do
      [packet] = Login7.encode(%{@fed_auth_login | fed_auth: %{token: "abc", echo: false}})

      # options byte 0x02: SecurityToken << 1, fFedAuthEcho clear
      assert binary_part(packet, byte_size(packet) - 12, 12) ==
               <<0x02, 6, 0, 0, 0, 97, 0, 98, 0, 99, 0, 255>>
    end

    test "FEDAUTH feature matches go-mssqldb's TestSendLoginWithFeatureExt reference" do
      # go-mssqldb tds_test.go, token "fedauthtoken" without echo:
      # FeatureId 2, FeatureDataLen 29, options 2, token length 24, UTF-16LE token
      go_mssqldb_fed_auth =
        <<2, 29, 0, 0, 0, 2, 24, 0, 0, 0, 102, 0, 101, 0, 100, 0, 97, 0, 117, 0, 116, 0, 104, 0,
          116, 0, 111, 0, 107, 0, 101, 0, 110, 0>>

      login = %{@fed_auth_login | fed_auth: %{token: "fedauthtoken", echo: false}}
      [packet] = Login7.encode(login)
      size = byte_size(go_mssqldb_fed_auth) + 1

      assert binary_part(packet, byte_size(packet) - size, size) ==
               go_mssqldb_fed_auth <> <<0xFF>>
    end

    test "an empty database is sent with a zero length" do
      [packet] = Login7.encode(%{@fed_auth_login | database: ""})

      # ibDatabase / cchDatabase
      assert binary_part(packet, 8 + 4 + 32 + 32, 4) == <<174, 0, 0, 0>>
    end

    test "a token larger than one packet is split across LOGIN7 packets" do
      token = String.duplicate("a", 3000)
      packets = Login7.encode(%{@fed_auth_login | fed_auth: %{token: token, echo: false}})

      assert [<<0x10, 0, _::binary>>, <<0x10, 1, _::binary>>] =
               Enum.map(packets, &IO.iodata_to_binary/1)

      payload =
        Enum.map_join(packets, fn packet ->
          <<_header::binary-8, data::binary>> = IO.iodata_to_binary(packet)
          data
        end)

      <<length::little-32, _::binary>> = payload
      assert length == byte_size(payload)

      assert :binary.part(payload, byte_size(payload) - 6_001, 6_001) ==
               :binary.copy(<<?a, 0>>, 3000) <> <<0xFF>>
    end

    test "a 6000 character token spans three packets with EOM only on the last" do
      token = String.duplicate("a", 6000)

      packets =
        %{@fed_auth_login | fed_auth: %{token: token, echo: false}}
        |> Login7.encode()
        |> Enum.map(&IO.iodata_to_binary/1)

      headers =
        for <<type, status, length::16, _spid::16, id, _window>> <> _ <- packets,
            do: {type, status, length, id}

      # 4088 bytes of data + 8 byte header per full packet, status 0x01 (EOM) last
      assert [{0x10, 0, 4096, 1}, {0x10, 0, 4096, 2}, {0x10, 1, last_length, 3}] = headers
      assert last_length == byte_size(List.last(packets))

      payload = Enum.map_join(packets, fn <<_header::binary-8, data::binary>> -> data end)
      <<length::little-32, _::binary>> = payload
      assert length == byte_size(payload)

      assert :binary.part(payload, byte_size(payload) - 12_001, 12_001) ==
               :binary.copy(<<?a, 0>>, 6000) <> <<0xFF>>
    end
  end
end
