defmodule DatetimeTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Parameter

  @tag timeout: 50_000

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  @date {2015, 4, 8}
  @time {15, 16, 23}
  @time_us {15, 16, 23, 123_456}
  @time_fsec {15, 16, 23, 1_234_567}
  @datetime {@date, @time}
  @datetime_us {@date, @time_us}
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

    assert [[nil]] ==
             "SELECT CAST(NULL AS datetime)"
             |> query([])

    assert [[~N[2014-06-20 10:21:42.000]]] ==
             "SELECT CAST('20140620 10:21:42 AM' AS datetime)"
             |> query([])

    assert [[nil]] ==
             "SELECT @n1"
             |> query([
               %Parameter{
                 name: "@n1",
                 value: nil,
                 type: :datetime
               }
             ])

    assert [[~N[2015-04-08 15:16:23.000]]] ==
             "SELECT @n1"
             |> query([
               %Parameter{
                 name: "@n1",
                 value: @datetime,
                 type: :datetime
               }
             ])

    assert [[~N[2015-04-08 15:16:23.123]]] ==
             "SELECT @n1"
             |> query([
               %Parameter{
                 name: "@n1",
                 value: @datetime_us,
                 type: :datetime
               }
             ])

    assert :ok =
             "INSERT INTO date_test VALUES (@1, @2)"
             |> query([
               %Parameter{
                 name: "@1",
                 value: nil,
                 type: :datetime
               },
               %Parameter{name: "@2", value: 0, type: :integer}
             ])

    query("DROP TABLE date_test", [])
  end

  test "smalldatetime", context do
    assert [[nil]] ==
             "SELECT CAST(NULL AS smalldatetime)"
             |> query([])

    assert [[~N[2014-06-20 10:40:00]]] ==
             "SELECT CAST('20140620 10:40 AM' AS smalldatetime)"
             |> query([])

    assert [[nil]] ==
             "SELECT @n1"
             |> query([
               %Parameter{
                 name: "@n1",
                 value: nil,
                 type: :smalldatetime
               }
             ])

    assert [[~N[2015-04-08 15:16:00]]] ==
             "SELECT @n1"
             |> query([
               %Parameter{
                 name: "@n1",
                 value: @datetime,
                 type: :smalldatetime
               }
             ])

    assert [[~N[2015-04-08 15:16:00]]] ==
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
    assert [[nil]] == query("SELECT CAST(NULL AS date)", [])

    assert [[~D[2014-06-20]]] ==
             query("SELECT CAST('20140620' AS date)", [])

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: nil, type: :date}
             ])

    assert [[~D[2015-04-08]]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @date,
                 type: :date
               }
             ])
  end

  test "time", context do
    assert [[nil]] == query("SELECT CAST(NULL AS time)", [])
    assert [[nil]] == query("SELECT CAST(NULL AS time(0))", [])
    assert [[nil]] == query("SELECT CAST(NULL AS time(6))", [])

    # Scale 7 -> clipped to microsecond (6 digits)
    assert [[~T[10:24:30.123456]]] ==
             query(
               "SELECT CAST('10:24:30.1234567' AS time)",
               []
             )

    assert [[~T[10:24:30]]] ==
             query(
               "SELECT CAST('10:24:30.1234567' AS time(0))",
               []
             )

    # Scale 7 -> same clipping
    assert [[~T[10:24:30.123456]]] ==
             query(
               "SELECT CAST('10:24:30.1234567' AS time(7))",
               []
             )

    assert [[~T[10:24:30.123457]]] ==
             query(
               "SELECT CAST('10:24:30.1234567' AS time(6))",
               []
             )

    assert [[~T[10:24:30.1]]] ==
             query(
               "SELECT CAST('10:24:30.1234567' AS time(1))",
               []
             )

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: nil, type: :time}
             ])

    # Old encode sends @time as scale 7 -> decode returns scale 6
    assert [[~T[15:16:23.000000]]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @time,
                 type: :time
               }
             ])

    # {15,16,23,123} at scale 7 -> 123 * 100ns = 12.3us = 12us
    assert [[~T[15:16:23.000012]]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: {15, 16, 23, 123},
                 type: :time
               }
             ])

    # @time_fsec = {15,16,23,1_234_567} at scale 7
    # 1234567 * 100ns = 123456.7us = 123456us
    assert [[~T[15:16:23.123456]]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @time_fsec,
                 type: :time
               }
             ])
  end

  test "datetime2", context do
    assert [[nil]] ==
             query("SELECT CAST(NULL AS datetime2)", [])

    assert [[nil]] ==
             query("SELECT CAST(NULL AS datetime2(0))", [])

    assert [[nil]] ==
             query("SELECT CAST(NULL AS datetime2(6))", [])

    # Scale 7 -> microsecond clipping
    assert [[~N[2015-04-08 15:16:23.000000]]] ==
             query(
               "SELECT CAST('20150408 15:16:23' AS datetime2)",
               []
             )

    assert [[~N[2015-04-08 15:16:23.420000]]] ==
             query(
               "SELECT CAST('20150408 15:16:23.42' AS datetime2)",
               []
             )

    assert [[~N[2015-04-08 15:16:23.420000]]] ==
             query(
               "SELECT CAST('20150408 15:16:23.42' AS datetime2(7))",
               []
             )

    assert [[~N[2015-04-08 15:16:23.420000]]] ==
             query(
               "SELECT CAST('20150408 15:16:23.42' AS datetime2(6))",
               []
             )

    assert [[~N[2015-04-08 15:16:23]]] ==
             query(
               "SELECT CAST('20150408 15:16:23.42' AS datetime2(0))",
               []
             )

    assert [[~N[2015-04-08 15:16:23.4]]] ==
             query(
               "SELECT CAST('20150408 15:16:23.42' AS datetime2(1))",
               []
             )

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: nil,
                 type: :datetime2
               }
             ])

    assert [[~N[2015-04-08 15:16:23.000000]]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @datetime,
                 type: :datetime2
               }
             ])

    # Scale 7 -> clipped to 6
    assert [[~N[2015-04-08 15:16:23.123456]]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: @datetime_fsec,
                 type: :datetime2
               }
             ])
  end

  test "implicit params", context do
    # datetime via old encode -> NaiveDateTime decode
    assert [[~N[2015-04-08 15:16:23.000]]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetime}
             ])

    # @datetime_us = {{2015,4,8},{15,16,23,123_456}} at scale 7
    # 123456 * 100ns = 12345.6us = 12345us -> ~N[...012345]
    assert [[~N[2015-04-08 15:16:23.012345]]] ==
             query("SELECT @n1", [
               %Parameter{name: "@n1", value: @datetime_us}
             ])

    # datetimeoffset returns DateTime struct
    [[result]] =
      query("SELECT @n1", [
        %Parameter{name: "@n1", value: @datetimeoffset}
      ])

    assert %DateTime{} = result

    [[result_fsec]] =
      query("SELECT @n1", [
        %Parameter{name: "@n1", value: @datetimeoffset_fsec}
      ])

    assert %DateTime{} = result_fsec
  end
end
