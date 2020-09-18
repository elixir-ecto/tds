defmodule DatetimeOffsetTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Types
  alias Tds.Parameter
  import Tds.Types.DateTimeOffset

  @tag timeout: 50000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  @date {2015, 4, 8}
  @time {15, 16, 23}
  @time_fsec {15, 16, 23, 1_234_567}
  @offset -240
  @datetimeoffset {@date, @time, @offset}
  @datetimeoffset_fsec {@date, @time_fsec, @offset}

  test "datetimeoffset", context do
    dts = [
      {{2020, 2, 28}, {13, 59, 59, 0}, 600},
      {{2020, 2, 28}, {13, 59, 59, 0}, 600},
      {{2020, 2, 28}, {13, 59, 59, 1}, 600},
      {{2020, 2, 28}, {13, 59, 59, 12}, 600},
      {{2020, 2, 28}, {13, 59, 59, 123}, 600},
      {{2020, 2, 28}, {13, 59, 59, 1234}, 600},
      {{2020, 2, 28}, {13, 59, 59, 12345}, 600},
      {{2020, 2, 28}, {13, 59, 59, 123_456}, 600},
      {{2020, 2, 28}, {13, 59, 59, 1_234_567}, 600},
      {{2020, 2, 28}, {13, 59, 59, 0}, -600},
      {{2020, 2, 28}, {13, 59, 59, 0}, -600},
      {{2020, 2, 28}, {13, 59, 59, 1}, -600},
      {{2020, 2, 28}, {13, 59, 59, 12}, -600},
      {{2020, 2, 28}, {13, 59, 59, 123}, -600},
      {{2020, 2, 28}, {13, 59, 59, 1234}, -600},
      {{2020, 2, 28}, {13, 59, 59, 12345}, -600},
      {{2020, 2, 28}, {13, 59, 59, 123_456}, -600},
      {{2020, 2, 28}, {13, 59, 59, 1_234_567}, -600},
      {{2020, 2, 28}, {13, 59, 59, 1_234_567}, 0},
      {{2020, 2, 28}, {13, 59, 59, 1_234_567}, 0}
    ]

    strs = [
      "'2020-02-28 23:59:59 +10:00'",
      "'2020-02-28 23:59:59.0000000 +10:00'",
      "'2020-02-28 23:59:59.0000001 +10:00'",
      "'2020-02-28 23:59:59.0000012 +10:00'",
      "'2020-02-28 23:59:59.0000123 +10:00'",
      "'2020-02-28 23:59:59.0001234 +10:00'",
      "'2020-02-28 23:59:59.0012345 +10:00'",
      "'2020-02-28 23:59:59.0123456 +10:00'",
      "'2020-02-28 23:59:59.1234567 +10:00'",
      "'2020-02-28 03:59:59 -10:00'",
      "'2020-02-28 03:59:59.0000000 -10:00'",
      "'2020-02-28 03:59:59.0000001 -10:00'",
      "'2020-02-28 03:59:59.0000012 -10:00'",
      "'2020-02-28 03:59:59.0000123 -10:00'",
      "'2020-02-28 03:59:59.0001234 -10:00'",
      "'2020-02-28 03:59:59.0012345 -10:00'",
      "'2020-02-28 03:59:59.0123456 -10:00'",
      "'2020-02-28 03:59:59.1234567 -10:00'",
      "'2020-02-28 13:59:59.1234567 +00:00'",
      "'2020-02-28 13:59:59.1234567Z'"
    ]

    Enum.zip(dts, strs)
    |> Enum.each(fn {dt, str} ->
      assert [[^dt]] = query("SELECT CAST(#{str} AS datetimeoffset(7))", [])
    end)

    assert nil == Types.encode_datetimeoffset(nil)

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

    assert [[{{2015, 4, 8}, {15, 16, 23, 1_234_567}, -240}]] ==
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
               %Parameter{name: "@1", value: nil, type: :datetimeoffset},
               %Parameter{name: "@2", value: nil, type: :datetimeoffset},
               %Parameter{name: "@3", value: nil, type: :datetimeoffset},
               %Parameter{name: "@4", value: nil, type: :datetimeoffset},
               %Parameter{name: "@5", value: nil, type: :datetimeoffset},
               %Parameter{name: "@6", value: nil, type: :datetimeoffset},
               %Parameter{name: "@7", value: nil, type: :datetimeoffset},
               %Parameter{name: "@8", value: nil, type: :datetimeoffset},
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

    assert [
             [
               {{2015, 4, 8}, {15, 16, 23, 0}, -240},
               {{2015, 4, 8}, {15, 16, 23, 1}, -240},
               {{2015, 4, 8}, {15, 16, 23, 12}, -240},
               {{2015, 4, 8}, {15, 16, 23, 123}, -240},
               {{2015, 4, 8}, {15, 16, 23, 1235}, -240},
               {{2015, 4, 8}, {15, 16, 23, 12346}, -240},
               {{2015, 4, 8}, {15, 16, 23, 123_457}, -240},
               {{2015, 4, 8}, {15, 16, 23, 123_4567}, -240}
             ]
           ] ==
             query(
               "SELECT zero, one, two, three, four, five, six, seven from datetimeoffset_test WHERE ver = 1"
             )

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

    # datetimeoffset with higher precision is rounded on insertion
    assert [
             [
               {{2015, 4, 8}, {15, 16, 23, 0}, 0},
               {{2015, 4, 8}, {15, 16, 23, 1}, 0},
               {{2015, 4, 8}, {15, 16, 23, 12}, 0},
               {{2015, 4, 8}, {15, 16, 23, 123}, 0},
               {{2015, 4, 8}, {15, 16, 23, 1235}, 0},
               {{2015, 4, 8}, {15, 16, 23, 12346}, 0},
               {{2015, 4, 8}, {15, 16, 23, 123_456}, 0},
               {{2015, 4, 8}, {15, 16, 23, 123_4560}, 0}
             ]
           ] ==
             query(
               "SELECT zero, one, two, three, four, five, six, seven from datetimeoffset_test WHERE ver = 2"
             )

    query("DROP TABLE datetimeoffset_test", [])
  end

  describe "datetimeoffset ecto type:" do
    test "cast/1" do
      [
        {~U[2020-02-28 23:59:59.000000Z], "2020-02-28 23:59:59.000000Z"},
        {~U[2020-02-28 23:59:59.00000Z], "2020-02-28 23:59:59.00000Z"},
        {~U[2020-02-28 23:59:59.0000Z], "2020-02-28 23:59:59.0000Z"},
        {~U[2020-02-28 23:59:59.000Z], "2020-02-28 23:59:59.000Z"},
        {~U[2020-02-28 23:59:59.00Z], "2020-02-28 23:59:59.00Z"},
        {~U[2020-02-28 23:59:59.0Z], "2020-02-28 23:59:59.0Z"},
        {~U[2020-02-28 23:59:59Z], "2020-02-28 23:59:59Z"},
        {~U[2020-02-28 23:59:59.1Z], "2020-02-28 23:59:59.1Z"},
        {~U[2020-02-28 23:59:59.10Z], "2020-02-28 23:59:59.10Z"},
        {~U[2020-02-28 23:59:59.100Z], "2020-02-28 23:59:59.100Z"},
        {~U[2020-02-28 23:59:59.1000Z], "2020-02-28 23:59:59.1000Z"},
        {~U[2020-02-28 23:59:59.10000Z], "2020-02-28 23:59:59.10000Z"},
        {~U[2020-02-28 23:59:59.100000Z], "2020-02-28 23:59:59.100000Z"},
        {~U[2020-02-28 23:59:59.12Z], "2020-02-28 23:59:59.12Z"},
        {~U[2020-02-28 23:59:59.123Z], "2020-02-28 23:59:59.123Z"},
        {~U[2020-02-28 23:59:59.1234Z], "2020-02-28 23:59:59.1234Z"},
        {~U[2020-02-28 23:59:59.12345Z], "2020-02-28 23:59:59.12345Z"},
        {~U[2020-02-28 23:59:59.123456Z], "2020-02-28 23:59:59.123456Z"},
        {~U[2020-02-28 23:59:59.999999Z], "2020-02-28 23:59:59.999999Z"}
      ]
      |> Enum.each(fn {dt, str} ->
        assert cast(dt) == {:ok, dt}
        assert cast(str) == {:ok, dt}
        assert cast!(dt) == dt
        assert cast!(str) == dt
      end)

      # NaiveDateTime unsupported
      assert cast(~N[2020-02-28 13:59:59.123456]) == :error
      assert cast!(~N[2020-02-28 13:59:59.123456]) == :error
    end

    test "load/1" do
      [
        {~U[2020-02-28 23:59:59Z], {{2020, 2, 28}, {23, 59, 59}, 600}},
        {~U[2020-02-28 23:59:59.1Z], {{2020, 2, 28}, {23, 59, 59, 1}, 600}},
        {~U[2020-02-28 23:59:59.12Z], {{2020, 2, 28}, {23, 59, 59, 12}, 600}},
        {~U[2020-02-28 23:59:59.123Z], {{2020, 2, 28}, {23, 59, 59, 123}, 600}},
        {~U[2020-02-28 23:59:59.1234Z],
         {{2020, 2, 28}, {23, 59, 59, 1234}, 600}},
        {~U[2020-02-28 23:59:59.12345Z],
         {{2020, 2, 28}, {23, 59, 59, 12345}, 600}},
        {~U[2020-02-28 23:59:59.123456Z],
         {{2020, 2, 28}, {23, 59, 59, 123_456}, 600}},
        {~U[2020-02-28 23:59:59.123456Z],
         {{2020, 2, 28}, {23, 59, 59, 1_234_567}, 600}},
        {~U[2020-02-28 23:59:59Z], {{2020, 2, 28}, {23, 59, 59}, -600}},
        {~U[2020-02-28 23:59:59.1Z], {{2020, 2, 28}, {23, 59, 59, 1}, -600}},
        {~U[2020-02-28 23:59:59.12Z], {{2020, 2, 28}, {23, 59, 59, 12}, -600}},
        {~U[2020-02-28 23:59:59.123Z],
         {{2020, 2, 28}, {23, 59, 59, 123}, -600}},
        {~U[2020-02-28 23:59:59.1234Z],
         {{2020, 2, 28}, {23, 59, 59, 1234}, -600}},
        {~U[2020-02-28 23:59:59.12345Z],
         {{2020, 2, 28}, {23, 59, 59, 12345}, -600}},
        {~U[2020-02-28 23:59:59.123456Z],
         {{2020, 2, 28}, {23, 59, 59, 123_456}, -600}},
        {~U[2020-02-28 23:59:59.123456Z],
         {{2020, 2, 28}, {23, 59, 59, 1_234_567}, -600}},
        {~U[2020-02-28 23:59:59Z], {{2020, 2, 28}, {23, 59, 59}, 0}},
        {~U[2020-02-28 23:59:59.1Z], {{2020, 2, 28}, {23, 59, 59, 1}, 0}},
        {~U[2020-02-28 23:59:59.12Z], {{2020, 2, 28}, {23, 59, 59, 12}, 0}},
        {~U[2020-02-28 23:59:59.123Z], {{2020, 2, 28}, {23, 59, 59, 123}, 0}},
        {~U[2020-02-28 23:59:59.1234Z], {{2020, 2, 28}, {23, 59, 59, 1234}, 0}},
        {~U[2020-02-28 23:59:59.12345Z],
         {{2020, 2, 28}, {23, 59, 59, 12345}, 0}},
        {~U[2020-02-28 23:59:59.123456Z],
         {{2020, 2, 28}, {23, 59, 59, 123_456}, 0}},
        {~U[2020-02-28 23:59:59.123456Z],
         {{2020, 2, 28}, {23, 59, 59, 1_234_567}, 0}}
      ]
      |> Enum.each(fn {dt, tuple} ->
        assert {:ok, dt} == load(tuple)
      end)
    end

    test "dump/1" do
      [
        ~U[2020-02-28 23:59:59Z],
        ~U[2020-02-28 23:59:59.1Z],
        ~U[2020-02-28 23:59:59.12Z],
        ~U[2020-02-28 23:59:59.123Z],
        ~U[2020-02-28 23:59:59.1234Z],
        ~U[2020-02-28 23:59:59.12345Z],
        ~U[2020-02-28 23:59:59.123456Z],
        ~U[2020-02-28 23:59:59.10Z],
        ~U[2020-02-28 23:59:59.100Z],
        ~U[2020-02-28 23:59:59.1000Z],
        ~U[2020-02-28 23:59:59.10000Z],
        ~U[2020-02-28 23:59:59.100000Z]
      ]
      |> Enum.each(fn dt ->
        {:ok, dumped} = dump(dt)
        assert {:ok, dt} == load(dumped)
      end)
    end

    test "autogenerate/0" do
      assert {{_, _, _}, {_, _, _, _}, 0} = autogenerate()
    end

    test "from_unix!/2" do
      assert from_unix!(0, :second) == ~U[1970-01-01 00:00:00Z]
    end

  end
end
