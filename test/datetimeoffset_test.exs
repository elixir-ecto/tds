defmodule DatetimeOffsetTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Parameter
  alias Tds.Types

  @tag timeout: 50_000

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  @date {2015, 4, 8}
  @time {15, 16, 23}
  @time_fsec {15, 16, 23, 1_234_567}
  @offset -240
  @datetimeoffset {@date, @time, @offset}
  @datetimeoffset_fsec {@date, @time_fsec, @offset}

  test "datetimeoffset", context do
    # Old Types encode/decode still works in tuple format
    assert nil == Types.encode_datetimeoffset(nil)

    assert [[nil]] ==
             query("SELECT CAST(NULL AS datetimeoffset)", [])

    assert [[nil]] ==
             query("SELECT CAST(NULL AS datetimeoffset(0))", [])

    assert [[nil]] ==
             query("SELECT CAST(NULL AS datetimeoffset(6))", [])

    # New handler returns DateTime structs
    # datetime2 returns NaiveDateTime
    assert [[~N[2015-04-08 15:16:23.420000]]] ==
             query(
               "SELECT CAST('20150408 15:16:23.42' AS datetime2)",
               []
             )

    # datetimeoffset with +0:00 offset -> decoded as UTC
    [[dto_zero]] =
      query(
        "SELECT CAST('2015-4-8 15:16:23.42 +0:00' as datetimeoffset(7))",
        []
      )

    assert %DateTime{} = dto_zero
    assert dto_zero.utc_offset == 0

    # datetimeoffset with +8:15 offset -> decoded as UTC
    [[dto_plus]] =
      query(
        "SELECT CAST('2015-4-8 15:16:23.42 +8:15' as datetimeoffset(7))",
        []
      )

    assert %DateTime{} = dto_plus
    assert dto_plus.utc_offset == 0

    # datetimeoffset with -8:15 offset -> decoded as UTC
    [[dto_minus]] =
      query(
        "SELECT CAST('2015-4-8 15:16:23.42 -8:15' as datetimeoffset(7))",
        []
      )

    assert %DateTime{} = dto_minus
    assert dto_minus.utc_offset == 0

    assert [[nil]] ==
             query("SELECT @n1", [
               %Parameter{
                 name: "@n1",
                 value: nil,
                 type: :datetimeoffset
               }
             ])

    [[dto_fsec]] =
      query("SELECT @n1", [
        %Parameter{
          name: "@n1",
          value: @datetimeoffset_fsec,
          type: :datetimeoffset
        }
      ])

    assert %DateTime{} = dto_fsec
    # Decode returns UTC (offset discarded on decode)
    assert dto_fsec.utc_offset == 0

    [[dto_base]] =
      query("SELECT @n1", [
        %Parameter{
          name: "@n1",
          value: @datetimeoffset,
          type: :datetimeoffset
        }
      ])

    assert %DateTime{} = dto_base
    assert dto_base.utc_offset == 0

    # Verify various scales decode to DateTime structs
    dts_strs = [
      "'2020-02-28 23:59:59 +10:00'",
      "'2020-02-28 23:59:59.0000000 +10:00'",
      "'2020-02-28 23:59:59.0000001 +10:00'",
      "'2020-02-28 03:59:59 -10:00'",
      "'2020-02-28 13:59:59.1234567 +00:00'",
      "'2020-02-28 13:59:59.1234567Z'"
    ]

    for str <- dts_strs do
      [[result]] =
        query(
          "SELECT CAST(#{str} AS datetimeoffset(7))",
          []
        )

      assert %DateTime{} = result
    end
  end

  test "database", context do
    query("DROP TABLE datetimeoffset_test", [])

    :ok =
      query(
        """
          CREATE TABLE datetimeoffset_test (
            zero datetimeoffset(0) NULL,
            one datetimeoffset(1) NULL,
            two datetimeoffset(2) NULL,
            three datetimeoffset(3) NULL,
            four datetimeoffset(4) NULL,
            five datetimeoffset(5) NULL,
            six datetimeoffset(6) NULL,
            seven datetimeoffset(7) NULL,
            ver int NOT NULL
            )
        """,
        []
      )

    assert :ok =
             "INSERT INTO datetimeoffset_test VALUES (@1, @2, @3, @4, @5, @6, @7, @8, @9)"
             |> query([
               %Parameter{
                 name: "@1",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@2",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@3",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@4",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@5",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@6",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@7",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{
                 name: "@8",
                 value: nil,
                 type: :datetimeoffset
               },
               %Parameter{name: "@9", value: 0, type: :integer}
             ])

    p = %Parameter{
      name: "@1",
      value: @datetimeoffset_fsec,
      type: :datetimeoffset
    }

    assert :ok =
             "INSERT INTO datetimeoffset_test VALUES (@1, @2, @3, @4, @5, @6, @7, @8, @9)"
             |> query([
               p,
               %Parameter{p | name: "@2"},
               %Parameter{p | name: "@3"},
               %Parameter{p | name: "@4"},
               %Parameter{p | name: "@5"},
               %Parameter{p | name: "@6"},
               %Parameter{p | name: "@7"},
               %Parameter{p | name: "@8"},
               %Parameter{name: "@9", value: 1, type: :integer}
             ])

    # All columns return DateTime structs with offset
    [[z, o, tw, th, fo, fi, si, se]] =
      query(
        "SELECT zero, one, two, three, four, five, six, seven " <>
          "from datetimeoffset_test WHERE ver = 1"
      )

    for dto <- [z, o, tw, th, fo, fi, si, se] do
      assert %DateTime{} = dto
      # Decode always returns UTC
      assert dto.utc_offset == 0
    end

    p = %Parameter{
      name: "@1",
      value: ~U[2015-04-08 15:16:23.123456Z],
      type: :datetimeoffset
    }

    assert :ok =
             "INSERT INTO datetimeoffset_test VALUES (@1, @2, @3, @4, @5, @6, @7, @8, @9)"
             |> query([
               p,
               %Parameter{p | name: "@2"},
               %Parameter{p | name: "@3"},
               %Parameter{p | name: "@4"},
               %Parameter{p | name: "@5"},
               %Parameter{p | name: "@6"},
               %Parameter{p | name: "@7"},
               %Parameter{p | name: "@8"},
               %Parameter{name: "@9", value: 2, type: :integer}
             ])

    [[z2, o2, tw2, th2, fo2, fi2, si2, se2]] =
      query(
        "SELECT zero, one, two, three, four, five, six, seven " <>
          "from datetimeoffset_test WHERE ver = 2"
      )

    for dto <- [z2, o2, tw2, th2, fo2, fi2, si2, se2] do
      assert %DateTime{} = dto
      assert dto.utc_offset == 0
    end

    query("DROP TABLE datetimeoffset_test", [])
  end
end
