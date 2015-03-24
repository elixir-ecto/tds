defmodule DatetimeTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  alias Tds.Connection, as: Conn

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

  test "datetime offset", context do
    assert [{{{2015, 3, 20},{16,0,0,0}}}] = query("SELECT CAST('2015-3-20 16:00:00 -4:00' as datetimeoffset(7))",[])
  end

  test "Decode Date and Time", context do
    assert [{{{2014, 06, 20}, {10, 21, 42, 0}}}] = query("SELECT CAST('20140620 10:21:42 AM' AS datetime)", [])
    assert [{{{2014, 06, 20}, {10, 21, 42, 2220000}}}] = query("SELECT CAST('20140620 10:21:42.222 AM' AS datetime2)", [])
    assert [{{10, 24, 30, 1234567}}] = query("SELECT CAST('10:24:30.1234567' AS time(7))", [])
    assert [{{{2014, 06, 20}, {10, 40, 00, 0}}}] = query("SELECT CAST('20140620 10:40 AM' AS smalldatetime)", [])
    assert [{{2014, 06, 20}}] = query("SELECT CAST('20140620' AS date)", [])
    assert [{nil}] = query("SELECT CAST(NULL AS date)", [])
  end

end
