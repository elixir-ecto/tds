defmodule QueryTest do
  use ExUnit.Case, async: true

  import Tds.TestHelper

  require Logger

  @tag timeout: 50_000

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

    Application.put_env(:tds, :text_encoder, Excoding)
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

  test "query returns Tds.Error with MSSQL error metadata on unique violation", context do
    query("DROP TABLE UniqueBangTable", [])

    assert :ok =
             query(
               "CREATE TABLE UniqueBangTable (id INT, email NVARCHAR(100), " <>
                 "CONSTRAINT UQ_UniqueBangTable_email UNIQUE (email))",
               []
             )

    assert :ok = query("INSERT INTO UniqueBangTable (id, email) VALUES (1, 'foo@bar.com')", [])

    err = query("INSERT INTO UniqueBangTable (id, email) VALUES (2, 'foo@bar.com')", [])
    assert %{number: 2627, msg_text: msg} = err.mssql
    assert msg =~ "UQ_UniqueBangTable_email"

    query("DROP TABLE dbo.UniqueBangTable", [])
  end

  test "query! re-raises Tds.Error preserving MSSQL error metadata", context do
    pid = context[:pid]

    query("DROP TABLE UniqueBangTable2", [])

    assert :ok =
             query(
               "CREATE TABLE UniqueBangTable2 (id INT, email NVARCHAR(100), " <>
                 "CONSTRAINT UQ_UniqueBangTable2_email UNIQUE (email))",
               []
             )

    assert :ok = query("INSERT INTO UniqueBangTable2 (id, email) VALUES (1, 'foo@bar.com')", [])

    err =
      try do
        Tds.query!(pid, "INSERT INTO UniqueBangTable2 (id, email) VALUES (2, 'foo@bar.com')", [])
        flunk("expected Tds.Error to be raised")
      rescue
        e in Tds.Error -> e
      end

    assert %{number: 2627, msg_text: msg} = err.mssql
    assert msg =~ "UQ_UniqueBangTable2_email"

    query("DROP TABLE dbo.UniqueBangTable2", [])
  end

  test "prepare! re-raises Tds.Error preserving MSSQL error metadata", context do
    pid = context[:pid]

    err =
      try do
        Tds.prepare!(pid, "SELECT * FROM UniqueBangPrepareMissingTable", [])
        flunk("expected Tds.Error to be raised")
      rescue
        e in Tds.Error -> e
      end

    assert %{number: 208, msg_text: msg} = err.mssql
    assert msg =~ "UniqueBangPrepareMissingTable"
  end

  test "execute! re-raises Tds.Error preserving MSSQL error metadata on unique violation",
       context do
    pid = context[:pid]

    query("DROP TABLE UniqueBangExecuteTable", [])

    assert :ok =
             query(
               "CREATE TABLE UniqueBangExecuteTable (id INT, email NVARCHAR(100), " <>
                 "CONSTRAINT UQ_UniqueBangExecuteTable_email UNIQUE (email))",
               []
             )

    assert :ok =
             query("INSERT INTO UniqueBangExecuteTable (id, email) VALUES (1, 'foo@bar.com')", [])

    {:ok, q} =
      Tds.prepare(
        pid,
        "INSERT INTO UniqueBangExecuteTable (id, email) VALUES (2, 'foo@bar.com')",
        []
      )

    err =
      try do
        Tds.execute!(pid, q, [], [])
        flunk("expected Tds.Error to be raised")
      rescue
        e in Tds.Error -> e
      end

    assert %{number: 2627, msg_text: msg} = err.mssql
    assert msg =~ "UQ_UniqueBangExecuteTable_email"

    query("DROP TABLE dbo.UniqueBangExecuteTable", [])
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

  test "table reader integration", context do
    assert {:ok, result} =
             Tds.query(
               context[:pid],
               "SELECT * FROM (VALUES (1, 'a'), (2, 'b'), (3, 'c')) AS tab (x, y)",
               []
             )

    assert [
             %{"x" => 1, "y" => "a"},
             %{"x" => 2, "y" => "b"},
             %{"x" => 3, "y" => "c"}
           ] ==
             result
             |> Table.to_rows()
             |> Enum.to_list()

    columns = Table.to_columns(result)
    assert Enum.to_list(columns["x"]) == [1, 2, 3]
    assert Enum.to_list(columns["y"]) == ["a", "b", "c"]

    assert {_, %{count: 3}, _} = Table.Reader.init(result)
  end
end
