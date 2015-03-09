defmodule BinaryTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  alias Tds.Connection, as: Conn
  alias Tds.Parameter

  @tag timeout: 50000

  setup do
    opts = [
      hostname: "sqlserver.local",
      username: "test_user",
      password: "passw0rd!",
      database: "test_db"
    ]
    {:ok, pid} = Conn.start_link(opts)
    {:ok, [pid: pid]}
  end

  test "Implicit Conversion of binary to datatypes", context do
    query("DROP TABLE bin_test", [])
    query("""
      CREATE TABLE bin_test (
        char char NULL,
        varchar varchar(max) NULL,
        nvarchar nvarchar(max) NULL,
        binary binary NULL,
        varbinary varbinary(max) NULL,
        uuid uniqueidentifier NULL
        )
    """, [])

    nvar = "World" |> :unicode.characters_to_binary(:utf8, {:utf16, :little})

    params = [
      %Parameter{name: "@1", value: "H", type: :binary},
      %Parameter{name: "@2", value: "ello", type: :binary},
      %Parameter{name: "@3", value: nvar, type: :binary},
      %Parameter{name: "@4", value: <<0>>, type: :binary},
      %Parameter{name: "@5", value: <<0, 1, 0, 1>>, type: :binary},
      %Parameter{name: "@6", value: <<0x82, 0x25, 0xF2, 0xA9, 0xAF, 0xBA, 0x45, 0xC5, 0xA4, 0x31, 0x86, 0xB9, 0xA8, 0x67, 0xE0, 0xF7>>, type: :uuid}
    ]
    
    query("INSERT INTO bin_test (char, varchar, nvarchar, binary, varbinary, uuid) VALUES (@1, @2, @3, @4, @5, @6)", params)
    assert [{"H", "ello", "World", <<0>>, <<0, 1, 0, 1>>, <<0x82, 0x25, 0xF2, 0xA9, 0xAF, 0xBA, 0x45, 0xC5, 0xA4, 0x31, 0x86, 0xB9, 0xA8, 0x67, 0xE0, 0xF7>>}] = query("SELECT TOP(1) * FROM bin_test", [])
    
    #query("DROP TABLE bin_test", [])
  end

  test "Binary NULL Types", context do
    query("DROP TABLE bin_test", [])
    query("""
      CREATE TABLE bin_test (
        char char NULL,
        varchar varchar(max) NULL,
        nvarchar nvarchar(max) NULL,
        binary binary NULL,
        varbinary varbinary(max) NULL,
        uuid uniqueidentifier NULL
        )
    """, [])
    params = [
      %Parameter{name: "@1", value: nil, type: :binary},
      %Parameter{name: "@2", value: nil, type: :binary},
      %Parameter{name: "@3", value: nil, type: :binary},
      %Parameter{name: "@4", value: nil, type: :binary},
      %Parameter{name: "@5", value: nil, type: :binary},
      %Parameter{name: "@6", value: nil, type: :binary}
    ]
    query("INSERT INTO bin_test (char, varchar, nvarchar, binary, varbinary, uuid) VALUES (@1, @2, @3, @4, @5, @6)", params)
    assert [{nil, nil, nil, nil, nil, nil}] = query("SELECT TOP(1) * FROM bin_test", [])
  end

end