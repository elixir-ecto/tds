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
                 <<16, 1, 0, 228, 0, 0, 1, 0, 220, 0, 0, 0, 4, 0, 0, 116, 0, 16, 0, 0, 4, 0, 0,
                 7, 0, 0, 3, 34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 4, 0, 0, 94, 0, 13,
                 0, 120, 0, 4, 0, 128, 0, 8, 0, 144, 0, 10, 0, 164, 0, 13, 0, 0, 0, 0, 0,
                 190, 0, 4, 0, 0, 0, 0, 0, 198, 0, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 116, 0, 101, 0, 115, 0, 116, 0, 46, 0, 104, 0,
                 111, 0, 115, 0, 116, 0, 46, 0, 99, 0, 111, 0, 109, 0, 116, 0, 101, 0, 115,
                 0, 116, 0, 162, 165, 179, 165, 146, 165, 146, 165, 210, 165, 83, 165, 130,
                 165, 227, 165, 69, 0, 108, 0, 105, 0, 120, 0, 105, 0, 114, 0, 32, 0, 84, 0,
                 68, 0, 83, 0, 115, 0, 111, 0, 109, 0, 101, 0, 46, 0, 104, 0, 111, 0, 115, 0,
                 116, 0, 46, 0, 99, 0, 111, 0, 109, 0, 79, 0, 68, 0, 66, 0, 67, 0, 109, 0,
                 121, 0, 95, 0, 100, 0, 97, 0, 116, 0, 97, 0, 98, 0, 97, 0, 115, 0, 101, 0>>

             ]
  end
end
