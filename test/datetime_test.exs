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
    date = {2015, 4, 8}
    time = {15, 16, 23, 42}
    offset = -240
    enc = Tds.Types.encode_time(time)
    assert time == Tds.Types.decode_time 7, enc

    enc = Tds.Types.encode_datetime2({date,time})
    assert {date,time} == Tds.Types.decode_datetime2 7, enc

    enc = Tds.Types.encode_datetimeoffset({date, time, offset})
    assert {date, time, offset} == Tds.Types.decode_datetimeoffset 7, enc

    assert [{{{2015, 4, 8}, {15, 16, 23, 4200000}}}] = query("SELECT CAST('20150408 15:16:23.42' AS datetime2)", [])
    assert [{{{2015, 4, 8}, {15, 16, 23, 4200000}, 0}}] = query("SELECT CAST('2015-4-8 15:16:23.42 +0:00' as datetimeoffset(7))",[])
    assert [{{{2015, 4, 8}, {7, 1, 23, 4200000}, 495}}] = query("SELECT CAST('2015-4-8 15:16:23.42 +8:15' as datetimeoffset(7))",[])
    assert [{{{2015, 4, 8}, {23, 31, 23, 4200000}, -495}}] = query("SELECT CAST('2015-4-8 15:16:23.42 -8:15' as datetimeoffset(7))",[])
  end

  test "Decode Date and Time", context do
    assert [{{{2014, 06, 20}, {10, 21, 42}}}] = query("SELECT CAST('20140620 10:21:42 AM' AS datetime)", [])
    assert [{{{2014, 06, 20}, {10, 21, 42, 2220000}}}] = query("SELECT CAST('20140620 10:21:42.222 AM' AS datetime2)", [])
    assert [{{10, 24, 30, 1234567}}] = query("SELECT CAST('10:24:30.1234567' AS time(7))", [])
    assert [{{{2014, 06, 20}, {10, 40}}}] = query("SELECT CAST('20140620 10:40 AM' AS smalldatetime)", [])
    assert [{{2014, 06, 20}}] = query("SELECT CAST('20140620' AS date)", [])
    assert [{nil}] = query("SELECT CAST(NULL AS date)", [])
  end

  test "Decode Date and Time", context do
    assert [{{{2014, 06, 20}, {10, 21, 42}}}] = query("SELECT CAST('20140620 10:21:42 AM' AS datetime)", [])
    assert [{{{2014, 06, 20}, {10, 21, 42, 2220000}}}] = query("SELECT CAST('20140620 10:21:42.222 AM' AS datetime2)", [])
    assert [{{10, 24, 30, 1234567}}] = query("SELECT CAST('10:24:30.1234567' AS time(7))", [])
    assert [{{{2014, 06, 20}, {10, 40, 00, 0}}}] = query("SELECT CAST('20140620 10:40 AM' AS smalldatetime)", [])
    assert [{{2014, 06, 20}}] = query("SELECT CAST('20140620' AS date)", [])
    assert [{nil}] = query("SELECT CAST(NULL AS date)", [])
  end
end
