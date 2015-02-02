defmodule QueryTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  alias Tds.Connection, as: Conn

  @tag timeout: 50000

  setup do
    opts = [
      hostname: "sqlserver.local",
      port: 4000,
      username: "test_user",
      password: "passw0rd!",
      database: "test_db"
    ]
    {:ok, pid} = Conn.start_link(opts)
    {:ok, [pid: pid]}
  end

  test "Decode Fixed Length Data types", context do
    query("DROP TABLE FixedLength", [])
    query("""
      CREATE TABLE FixedLength (
        TinyInt tinyint, 
        Bit bit, 
        SmallInt smallint, 
        Int int, 
        SmallDateTime smalldatetime, 
        Real real, 
        Money money, 
        DateTime datetime, 
        Float float, 
        SmallMoney smallmoney, 
        BitInt bigint)
      """, [])
    query("INSERT INTO FixedLength VALUES(1, 0, 12, 100, '2014-01-10 12:30:00', 5.2, '$-40,532.5367', '2014-01-11 11:34:25', 5.6, '$6.3452', 1000)", []);
    assert [{1, false, 12, 100, {{2014, 01, 10},{12, 30, 00}}, 5.2, -40532.5367, {{2014, 01, 11},{11, 34, 25}}, 5.6, 6.3452 , 1000}] = query("SELECT TOP(1) * FROM FixedLength", [])
    query("DROP TABLE FixedLength", [])
  end

  test "Decode basic types", context do
    assert [{1}] = query("SELECT 1", [])
    assert [{1}] = query("SELECT 1 as 'number'", [])
    assert [{1, 1}] = query("SELECT 1, 1", [])
    assert [{-1}] = query("SELECT -1", [])
    assert [{10000000000000}] = query("select CAST(10000000000000 AS bigint)", [])
    assert [{"string"}] = query("SELECT 'string'", [])
    assert [{"ẽstring"}] = query("SELECT N'ẽstring'", [])
    assert [{true, false}] = query("SELECT CAST(1 AS BIT), CAST(0 AS BIT)", [])
    assert [{<<0x82, 0x25, 0xF2, 0xA9, 0xAF, 0xBA, 0x45, 0xC5, 0xA4, 0x31, 0x86, 0xB9, 0xA8, 0x67, 0xE0, 0xF7>>}] = query("SELECT CAST('8225F2A9-AFBA-45C5-A431-86B9A867E0F7' AS uniqueidentifier)", [])
  end

  test "Decode NULL", context do
    assert [{nil}] = query("SELECT NULL", [])
    assert [{nil}] = query("SELECT CAST(NULL AS BIT)", [])
    assert [{nil}] = query("SELECT CAST(NULL AS VARCHAR)", [])
    assert [{nil}] = query("SELECT CAST(NULL AS datetime)", [])
    query("SELECT CAST('1' AS VARCHAR)", [])
  end

  test "Decode Date and Time", context do
    assert [{{{2014, 06, 20}, {10, 21, 42}}}] = query("SELECT CAST('20140620 10:21:42 AM' AS datetime)", [])
    assert [{{{2014, 06, 20}, {10, 40, 00}}}] = query("SELECT CAST('20140620 10:40 AM' AS smalldatetime)", [])
    assert [{{2014, 06, 20}}] = query("SELECT CAST('20140620' AS date)", [])
    assert [{nil}] = query("SELECT CAST(NULL AS date)", [])
  end

  # # test "Decode Time", _context do

  # # end

  test "Create Tables", context do
    query("DROP TABLE MyTable", [])
    assert :ok = query("CREATE TABLE MyTable (TableId int)", [])
    assert :ok = query("DROP TABLE dbo.MyTable", [])
  end

  test "Large Result Set", context do
    query("DROP TABLE MyTable", [])
    assert :ok = query("CREATE TABLE MyTable (TableId int)", [])
    for n <- 1..100 do
      assert :ok = query("INSERT INTO MyTable VALUES (#{n})", [])
    end

    assert Enum.count(query("SELECT * FROM MyTable", [])) == 100
    assert :ok = query("DROP TABLE dbo.MyTable", [])
  end

  test "Empty Result Set", context do
    query("DROP TABLE MyTable", [])
    query("CREATE TABLE MyTable (TableId int)", [])
    assert :ok = query("SELECT * FROM MyTable", [])
  end

  test "fail for incorrect syntax", context do
    assert %Tds.Error{} = query("busted", [])
  end

  test "connection works after failure", context do
    assert %Tds.Error{} = query("busted", [])
    assert [{1}] = query("SELECT 1", [])
  end

end
