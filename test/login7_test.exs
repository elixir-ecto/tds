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

  test "encode login7 message with federated authentication" do
    nonce = :binary.copy(<<0xAB>>, 32)

    login = %Tds.Protocol.Login7{
      app_name: "Elixir TDS",
      client_language_code_id: <<9, 4, 0, 0>>,
      client_pid: <<0, 0, 3, 34>>,
      client_time_zone: <<0, 0, 0, 0>>,
      client_version: <<4, 0, 0, 7>>,
      connection_id: <<0, 0, 0, 0>>,
      database: "my_database",
      fed_auth_echo: true,
      fed_auth_token: "access-token",
      hostname: "test.host.com",
      nonce: nonce,
      option_flags_1: <<0>>,
      option_flags_2: <<0>>,
      option_flags_3: <<0x10>>,
      packet_size: <<0, 16, 0, 0>>,
      password: "",
      servername: "some.host.com",
      tds_version: <<4, 0, 0, 116>>,
      type_flags: <<0>>,
      username: ""
    }

    # packet header: type 0x10, status EOM, length 275 (263 + 12, since the
    # UCS/UTF-16LE token is twice the byte size of the raw ASCCI token)
    # LOGIN7 Length
    # fixed login, OptionFlags3 has fExtension (0x10) set
    # offset table, ibExtension/cbExtension point to the extension block
    # variable data: host, app name, server name, ODBC, database
    # extension: ibFeatureExtLong DWORD pointing to the FeatureExt block
    # FeatureExt: FEDAUTH (0x02), data len, Options (0x03 = bFedAuthLibrary
    # 0x01 << 1 | fFedAuthEcho 0x01), token length (UTF-16LE byte size),
    # token (UTF-16LE), nonce, terminator
    token_bin = Tds.Encoding.UCS2.from_string("access-token")
    feature_data_len = 1 + 4 + byte_size(token_bin) + byte_size(nonce)

    expected =
      <<16, 1, 1, 19, 0, 0, 1, 0>> <>
        <<11, 1, 0, 0>> <>
        <<4, 0, 0, 116, 0, 16, 0, 0, 4, 0, 0, 7, 0, 0, 3, 34, 0, 0, 0, 0>> <>
        <<0, 0, 0, 16, 0, 0, 0, 0, 9, 4, 0, 0>> <>
        <<94, 0, 13, 0>> <>
        <<120, 0, 0, 0>> <>
        <<120, 0, 0, 0>> <>
        <<120, 0, 10, 0>> <>
        <<140, 0, 13, 0>> <>
        <<196, 0, 4, 0>> <>
        <<166, 0, 4, 0>> <>
        <<0, 0, 0, 0>> <>
        <<174, 0, 11, 0>> <>
        <<0, 0, 0, 0, 0, 0>> <>
        <<0, 0, 0, 0>> <>
        <<0, 0, 0, 0>> <>
        <<0, 0, 0, 0>> <>
        <<0, 0, 0, 0>> <>
        <<116, 0, 101, 0, 115, 0, 116, 0, 46, 0>> <>
        <<104, 0, 111, 0, 115, 0, 116, 0, 46, 0>> <>
        <<99, 0, 111, 0, 109, 0>> <>
        <<69, 0, 108, 0, 105, 0, 120, 0, 105, 0, 114, 0, 32, 0, 84, 0, 68, 0, 83, 0>> <>
        <<115, 0, 111, 0, 109, 0, 101, 0, 46, 0>> <>
        <<104, 0, 111, 0, 115, 0, 116, 0, 46, 0>> <>
        <<99, 0, 111, 0, 109, 0>> <>
        <<79, 0, 68, 0, 66, 0, 67, 0>> <>
        <<109, 0, 121, 0, 95, 0, 100, 0, 97, 0, 116, 0, 97, 0, 98, 0, 97, 0, 115, 0, 101, 0>> <>
        <<200, 0, 0, 0>> <>
        <<2, feature_data_len::little-size(32), 3, byte_size(token_bin)::little-size(32)>> <>
        token_bin <> nonce <> <<255>>

    assert Login7.encode(login) == [expected]
  end

  test "new/1 builds a federated authentication login from options" do
    nonce = :binary.copy(<<0xAB>>, 32)

    login =
      Login7.new(
        access_token: "token",
        fed_auth_required: true,
        nonce: nonce,
        hostname: "some.host.com",
        database: "db"
      )

    assert login.username == ""
    assert login.password == ""
    assert login.option_flags_3 == <<0x10>>
    assert login.fed_auth_token == "token"
    assert login.fed_auth_echo
    assert login.nonce == nonce

    login = Login7.new(username: "sa", password: "pw", hostname: "h", database: "db")

    assert login.username == "sa"
    assert login.password == "pw"
    assert login.option_flags_3 == <<0>>
    assert is_nil(login.fed_auth_token)
    refute login.fed_auth_echo
  end
end
