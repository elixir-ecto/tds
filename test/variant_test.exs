defmodule VariantTest do
  import Tds.TestHelper
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  test "sql_variant NULL", context do
    assert [[nil]] = query("SELECT CAST(NULL AS sql_variant)", [])
  end

  test "sql_variant SERVERPROPERTY", context do
    assert [[edition]] = query("SELECT SERVERPROPERTY('EngineEdition')", [])
    assert is_integer(edition)
  end

  test "sql_variant integer and bit base types", context do
    assert [[255, -7, 42, -9_000_000_000, true]] =
             query(
               """
               SELECT CAST(CAST(255 AS tinyint) AS sql_variant),
                 CAST(CAST(-7 AS smallint) AS sql_variant),
                 CAST(42 AS sql_variant),
                 CAST(CAST(-9000000000 AS bigint) AS sql_variant),
                 CAST(CAST(1 AS bit) AS sql_variant)
               """,
               []
             )
  end

  test "sql_variant numeric base types", context do
    assert [[decimal, numeric, 12.3456, -1.5, 1.5, 2.25]] =
             query(
               """
               SELECT CAST(CAST(-12.345 AS decimal(10, 3)) AS sql_variant),
                 CAST(CAST(1.25 AS numeric(5, 2)) AS sql_variant),
                 CAST(CAST(12.3456 AS money) AS sql_variant),
                 CAST(CAST(-1.5 AS smallmoney) AS sql_variant),
                 CAST(CAST(1.5 AS real) AS sql_variant),
                 CAST(CAST(2.25 AS float) AS sql_variant)
               """,
               []
             )

    assert Decimal.equal?(decimal, Decimal.new("-12.345"))
    assert Decimal.equal?(numeric, Decimal.new("1.25"))
  end

  test "sql_variant date and time base types", context do
    assert [
             [
               {2026, 11, 2},
               {13, 45, 30, 1_234_567},
               {{2026, 11, 2}, {13, 45, 30, 12}},
               {{2026, 11, 2}, {11, 45, 30, 123}, 120},
               {{2026, 11, 2}, {13, 45, 0, 0}},
               {{2026, 11, 2}, {13, 45, 30, 0}}
             ]
           ] =
             query(
               """
               SELECT CAST(CAST('2026-11-02' AS date) AS sql_variant),
                 CAST(CAST('13:45:30.1234567' AS time(7)) AS sql_variant),
                 CAST(CAST('2026-11-02T13:45:30.12' AS datetime2(2)) AS sql_variant),
                 CAST(CAST('2026-11-02T13:45:30.123+02:00' AS datetimeoffset(3)) AS sql_variant),
                 CAST(CAST('2026-11-02T13:45:00' AS smalldatetime) AS sql_variant),
                 CAST(CAST('2026-11-02T13:45:30' AS datetime) AS sql_variant)
               """,
               []
             )
  end

  test "sql_variant string, binary and uniqueidentifier base types", context do
    uuid = Tds.Types.UUID.bingenerate()
    {:ok, uuid_string} = Tds.Types.UUID.load(uuid)

    assert [["ab  ", "plain", "résumé", "ñ ", <<0xDE, 0xAD, 0xBE, 0xEF>>, <<0xAB, 0, 0>>, ^uuid]] =
             query(
               """
               SELECT CAST(CAST('ab' AS char(4)) AS sql_variant),
                 CAST('plain' AS sql_variant),
                 CAST(N'résumé' AS sql_variant),
                 CAST(CAST(N'ñ' AS nchar(2)) AS sql_variant),
                 CAST(0xDEADBEEF AS sql_variant),
                 CAST(CAST(0xAB AS binary(3)) AS sql_variant),
                 CAST(CAST('#{uuid_string}' AS uniqueidentifier) AS sql_variant)
               """,
               []
             )
  end
end
