defmodule QueryTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  @tag timeout: 50000

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  test "Decode Fixed Length Data types", context do
    query("DROP TABLE FixedLength", [])

    query(
      """
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
      """,
      []
    )

    query(
      """
      INSERT INTO FixedLength
      VALUES(
        1,
        0,
        12,
        100,
        '2014-01-10T12:30:00',
        0.5,
        '-822,337,203,685,477.5808',
        '2014-01-11T11:34:25',
        5.6,
        '$-214,748.3648',
        1000
      )
      """,
      []
    )

    assert [
             [
               1,
               false,
               12,
               100,
               {{2014, 01, 10}, {12, 30, 0, 0}},
               0.5,
               -822_337_203_685_477.5808,
               {{2014, 01, 11}, {11, 34, 25, 0}},
               5.6,
               -214_748.3648,
               1000
             ]
           ] == query("SELECT TOP(1) * FROM FixedLength", [])

    query("DROP TABLE FixedLength", [])
  end

  test "Decode basic types", context do
    assert [[1]] = query("SELECT 1", [])
    assert [[1]] = query("SELECT 1 as 'number'", [])
    assert [[1, 1]] = query("SELECT 1, 1", [])
    assert [[-1]] = query("SELECT -1", [])

    assert [[10_000_000_000_000]] = query("select CAST(10000000000000 AS bigint)", [])

    assert [["string"]] = query("SELECT 'string'", [])

    Application.put_env(:tds, :text_encoder, Tds.Encoding)
    assert [["ẽstring"]] = query("SELECT N'ẽstring'", [])
    Application.delete_env(:tds, :text_encoder)

    assert [[true, false]] = query("SELECT CAST(1 AS BIT), CAST(0 AS BIT)", [])
    uuid = Tds.Types.UUID.bingenerate()
    {:ok, uuid_string} = Tds.Types.UUID.load(uuid)

    assert [[^uuid]] =
             query(
               """
               SELECT
               CAST('#{uuid_string}' AS uniqueidentifier)
               """,
               []
             )
  end

  test "Decode NULL", context do
    assert [[nil]] = query("SELECT NULL", [])
    assert [[nil]] = query("SELECT CAST(NULL AS BIT)", [])
    assert [[nil]] = query("SELECT CAST(NULL AS VARCHAR)", [])
    assert [[nil]] = query("SELECT CAST(NULL AS datetime)", [])
    query("SELECT CAST('1' AS VARCHAR)", [])
  end

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
    assert [[1]] = query("SELECT 1", [])
  end

  test "char nulls", context do
    assert [[nil]] = query("SELECT CAST(NULL as nvarchar(255))", [])
  end

  describe "execution mode" do
    test ":prepare_execute" do
      opts = Keyword.put(opts(), :execution_mode, :prepare_execute)

      {:ok, pid} = Tds.start_link(opts)
      context = [pid: pid]

      params = [%Tds.Parameter{name: "@1", value: 1}]
      assert [[1]] = query("SELECT 1 WHERE 1 = @1", params, opts)
    end

    test ":executesql" do
      opts =
        opts()
        |> Keyword.put(:execution_mode, :executesql)

      {:ok, pid} = Tds.start_link(opts)
      context = [pid: pid]

      params = [%Tds.Parameter{name: "@1", value: 1}]
      assert [[1]] = query("SELECT 1 WHERE 1 = @1", params, opts)
    end

    test "unknown errors out" do
      opts = Keyword.put(opts(), :execution_mode, :invalid)

      {:ok, pid} = Tds.start_link(opts)
      context = [pid: pid]

      params = [%Tds.Parameter{name: "@1", value: 1}]

      assert %Tds.Error{
               message:
                 "Unknown execution mode :invalid, please check your config.Supported modes are :prepare_execute and :executesql"
             } = query("SELECT 1 WHERE 1 = @1", params, opts)
    end
  end
end
