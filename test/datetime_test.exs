defmodule DatetimeTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Types
  alias Tds.Parameter

  @tag timeout: 50000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  @date {2015, 4, 8}
  @time {15, 16, 23}
  @time_fsec {15, 16, 23, 123_456}
  @datetime {@date, @time}
  @datetime_fsec {@date, @time_fsec}
  @offset -240
  @datetimeoffset {@date, @time, @offset}
  @datetimeoffset_fsec {@date, @time_fsec, @offset}

  test "datetime", context do
    query("DROP TABLE date_test", [])

    :ok =
      query(
        """
          CREATE TABLE date_test (
            created_at datetime NULL,
            ver int NOT NULL
            )
        """,
        []
      )

    assert nil == Types.encode_datetime(nil)

    assert {@date, {15, 16, 23, 0}} ==
             @datetime
             |> Types.encode_datetime()
             |> Types.decode_datetime()

    assert {@date, {15, 16, 23, 123_333}} ==
             @datetime_fsec
             |> Types.encode_datetime()
             |> Types.decode_datetime()

    assert [[nil]] ==
             "SELECT CAST(NULL AS datetime)"
             |> query([])

    assert [[{{2014, 06, 20}, {10, 21, 42, 0}}]] ==
             "SELECT CAST('20140620 10:21:42 AM' AS datetime)"
             |> query([])

    assert [[nil]] ==
             "SELECT @n1"
             |> query([%Parameter{name: "@n1", value: nil, type: :datetime}])

    assert [[{{2015, 4, 8}, {15, 16, 23, 0}}]] ==
             "SELECT @n1"
             |> query([
               %Parameter{name: "@n1", value: @datetime, type: :datetime}
             ])

    assert [[{{2015, 4, 8}, {15, 16, 23, 123_333}}]] ==
             "SELECT @n1"
             |> query([
               %Parameter{name: "@n1", value: @datetime_fsec, type: :datetime}
             ])

    assert :ok =
             "INSERT INTO date_test VALUES (@1, @2)"
             |> query([
               %Parameter{name: "@1", value: nil, type: :datetime},
               %Parameter{name: "@2", value: 0, type: :integer}
             ])

    query("DROP TABLE date_test", [])
  end

  test "smalldatetime", context do
    assert nil == Types.encode_smalldatetime(nil)

    assert {@date, {15, 16, 0, 0}} ==
             @datetime
             |> Types.encode_smalldatetime()
             |> Types.decode_smalldatetime()

    assert [[nil]] ==
             "SELECT CAST(NULL AS smalldatetime)"
             |> query([])

    assert [[{{2014, 06, 20}, {10, 40, 0, 0}}]] ==
             "SELECT CAST('20140620 10:40 AM' AS smalldatetime)"
             |> query([])

    assert [[nil]] ==
             "SELECT @n1"
             |> query([
               %Parameter{name: "@n1", value: nil, type: :smalldatetime}
             ])

    assert [[{{2015, 4, 8}, {15, 16, 0, 0}}]] ==
             "SELECT @n1"
             |> query([
               %Parameter{name: "@n1", value: @datetime, type: :smalldatetime}
             ])

    assert [[{{2015, 4, 8}, {15, 16, 0, 0}}]] ==
             "SELECT @n1"
             |> query([
               %Parameter{
                 name: "@n1",
                 value: @datetime_fsec,
                 type: :smalldatetime
               }
             ])
  end

  test "date", context do
    assert nil == Types.encode_date(nil)
    enc = Types.encode_date(@date)
    assert @date == Types.decode_date(enc)

    assert [[nil]] == query("SELECT CAST(NULL AS date)", [])
    assert [[{2014, 06, 20}]] == query("SELECT CAST('20140620' AS date)", [])

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: nil, type: :date}
             ])

    assert [[{2015, 4, 8}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @date, type: :date}
             ])
  end

  test "time", context do
    assert {nil, 0} == Types.encode_time(nil)

    {bin, scale} = Types.encode_time(@time)
    assert {15, 16, 23, 0} == Types.decode_time(scale, bin)

    {bin, scale} = Types.encode_time(@time_fsec, 7)
    assert {15, 16, 23, 123_456} == Types.decode_time(scale, bin)

    {bin, scale} = Types.encode_time(@time_fsec, 6)
    assert {15, 16, 23, 123_456} == Types.decode_time(scale, bin)

    assert [[nil]] == query("SELECT CAST(NULL AS time)", [])
    assert [[nil]] == query("SELECT CAST(NULL AS time(0))", [])
    assert [[nil]] == query("SELECT CAST(NULL AS time(6))", [])

    assert [[{10, 24, 30, 1_234_567}]] ==
             query("SELECT CAST('10:24:30.1234567' AS time)", [])

    assert [[{10, 24, 30, 0}]] ==
             query("SELECT CAST('10:24:30.1234567' AS time(0))", [])

    assert [[{10, 24, 30, 1_234_567}]] ==
             query("SELECT CAST('10:24:30.1234567' AS time(7))", [])

    assert [[{10, 24, 30, 123_457}]] ==
             query("SELECT CAST('10:24:30.1234567' AS time(6))", [])

    assert [[{10, 24, 30, 1}]] ==
             query("SELECT CAST('10:24:30.1234567' AS time(1))", [])

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: nil, type: :time}
             ])

    assert [[{15, 16, 23, 0}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @time, type: :time}
             ])

    assert [[{15, 16, 23, 123}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: {15, 16, 23, 123}, type: :time}
             ])

    assert [[{15, 16, 23, 123_456}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @time_fsec, type: :time}
             ])
  end

  test "datetime2", context do
    assert {nil, 0} == Types.encode_datetime2(nil)

    {dt, scale} = Types.encode_datetime2(@datetime)
    assert {@date, {15, 16, 23, 0}} == Types.decode_datetime2(scale, dt)

    {dt, scale} = Types.encode_datetime2(@datetime_fsec)
    assert @datetime_fsec == Types.decode_datetime2(scale, dt)

    {dt, scale} = Types.encode_datetime2({@date, {131, 56, 23, 0}}, 0)
    assert {@date, {131, 56, 23, 0}} == Types.decode_datetime2(scale, dt)

    assert [[nil]] == query("SELECT CAST(NULL AS datetime2)", [])
    assert [[nil]] == query("SELECT CAST(NULL AS datetime2(0))", [])
    assert [[nil]] == query("SELECT CAST(NULL AS datetime2(6))", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 0}}]] ==
             query("SELECT CAST('20150408 15:16:23' AS datetime2)", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 4_200_000}}]] ==
             query("SELECT CAST('20150408 15:16:23.42' AS datetime2)", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 4_200_000}}]] ==
             query("SELECT CAST('20150408 15:16:23.42' AS datetime2(7))", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 420_000}}]] ==
             query("SELECT CAST('20150408 15:16:23.42' AS datetime2(6))", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 0}}]] ==
             query("SELECT CAST('20150408 15:16:23.42' AS datetime2(0))", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 4}}]] ==
             query("SELECT CAST('20150408 15:16:23.42' AS datetime2(1))", [])

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: nil, type: :datetime2}
             ])

    assert [[{{2015, 4, 8}, {15, 16, 23, 0}}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetime, type: :datetime2}
             ])

    assert [[{{2015, 4, 8}, {15, 16, 23, 123_456}}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetime_fsec, type: :datetime2}
             ])
  end

  test "datetime offset", context do
    assert nil == Types.encode_datetimeoffset(nil)
    enc = Types.encode_datetimeoffset(@datetimeoffset)

    assert {@date, {15, 16, 23, 0}, @offset} ==
             Types.decode_datetimeoffset(7, enc)

    assert @datetimeoffset_fsec ==
             Types.decode_datetimeoffset(
               7,
               Types.encode_datetimeoffset(@datetimeoffset_fsec)
             )

    assert [[nil]] == query("SELECT CAST(NULL AS datetimeoffset)", [])
    assert [[nil]] == query("SELECT CAST(NULL AS datetimeoffset(0))", [])
    assert [[nil]] == query("SELECT CAST(NULL AS datetimeoffset(6))", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 4_200_000}}]] ==
             query("SELECT CAST('20150408 15:16:23.42' AS datetime2)", [])

    assert [[{{2015, 4, 8}, {15, 16, 23, 4_200_000}, 0}]] ==
             query(
               "SELECT CAST('2015-4-8 15:16:23.42 +0:00' as datetimeoffset(7))",
               []
             )

    assert [[{{2015, 4, 8}, {7, 1, 23, 4_200_000}, 495}]] ==
             query(
               "SELECT CAST('2015-4-8 15:16:23.42 +8:15' as datetimeoffset(7))",
               []
             )

    assert [[{{2015, 4, 8}, {23, 31, 23, 4_200_000}, -495}]] ==
             query(
               "SELECT CAST('2015-4-8 15:16:23.42 -8:15' as datetimeoffset(7))",
               []
             )

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: nil, type: :datetimeoffset}
             ])

    assert [[{{2015, 4, 8}, {15, 16, 23, 123_456}, -240}]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @datetimeoffset_fsec,
                 type: :datetimeoffset
               }
             ])

    assert [[{{2015, 4, 8}, {15, 16, 23, 0}, -240}]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @datetimeoffset,
                 type: :datetimeoffset
               }
             ])
  end

  test "implicit params", context do
    assert [[{{2015, 4, 8}, {15, 16, 23, 0}}]] ==
             query("SELECT @n1", [%Parameter{name: "@n1", value: @datetime}])

    # #datetime_fsec {_,_,_,}, {_,_,_,_}
    assert [[{{2015, 4, 8}, {15, 16, 23, 123_456}}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetime_fsec}
             ])

    # datetime_fsec {_,_,_,}, {_,_,_}, _
    assert [[{{2015, 4, 8}, {15, 16, 23, 0}, -240}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetimeoffset}
             ])

    # datetime_fsec {_,_,_,}, {_,_,_,_}, _
    assert [[{{2015, 4, 8}, {15, 16, 23, 123_456}, -240}]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetimeoffset_fsec}
             ])
  end
end
