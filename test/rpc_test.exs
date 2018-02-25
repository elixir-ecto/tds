defmodule RPCTest do
  @moduledoc false
  import Tds.TestHelper
  require Logger
  use ExUnit.Case
  alias Tds.Parameter

  @tag timeout: 50_000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    # |> Keyword.put(:after_connect, {Tds, :query!, ["SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED", []]})
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  describe "parametrized queries" do
    test "with positiove and negative integer numbers", context do
      # Integers

      nums = [
        -9_223_372_036_854_775_807,
        -20_080_906_120_000,
        -4_294_967_296,
        -65_536,
        -256,
        -1,
        0,
        1,
        256,
        65_536,
        4_294_967_296,
        20_080_906_120_000,
        9_223_372_036_854_775_807
      ]

      Enum.each(nums, fn num ->
        assert [[num]] ==
                 query("SELECT cast(@n1 as bigint)", [%Parameter{name: "@n1", value: num, type: :integer}])
      end)

      query("""
      IF OBJECT_ID('int_test') IS NOT NULL DROP TABLE int_test;
      CREATE TABLE int_test (
        val bigint
      )
      """, [])
      Enum.each(nums, fn (num) -> query("insert into int_test values (@n1)", [%Parameter{name: "@n1", value: num}]) end)
      
      result = Enum.map(nums, fn (num) -> [num] end)
      assert result == query("SELECT val FROM int_test ORDER BY val asc", [])
      query("IF OBJECT_ID('int_test') IS NOT NULL DROP TABLE int_test;", [])
    end

    test "should raise ArgumentError if erlang integer value is not in range -9,223,372,036,854,775,807..9,223,372,036,854,775,807", _context do
      nums = [
        -11_111_111_111_111_111_111_111_111_111_111_111_111,
        11_111_111_111_111_111_111_111_111_111_111_111_111
      ]
      Enum.each(nums, fn (num) ->
        assert_raise(ArgumentError, fn ->
          Tds.Types.encode_data("@1", num, :integer)
        end)
      end)
    end

    test "with decimal numbers", context do
      # Decimals
      nums = [
        -11_111_111_111_111_111_111_111_111_111_111_111_111,
        -1.1111111111111111111111111111111111111,
        -1.111111111111111111111111111,
        -1.111111111111111111,
        -1.11111111,
        1.11111111,
        1.111111111111111111,
        1.111111111111111111111111111,
        1.1111111111111111111111111111111111111,
        11_111_111_111_111_111_111_111_111_111_111_111_111
      ]

      Enum.each(nums, fn num ->
        assert [[Decimal.new("#{num}")]] ==
                 query("SELECT @n1", [
                   %Parameter{name: "@n1", value: Decimal.new("#{num}")}
                 ])
      end)
    end

    test "with varchar string", context do
      # VarChar Strings
      strs = [
        "hello",
        "'",
        "!@#$%^&*()",
        ""
      ]

      Enum.each(strs, fn str ->
        assert [[str]] ==
                 query("SELECT @n1", [
                   %Parameter{name: "@n1", value: str, type: :string}
                 ])
      end)
    end

    test "with nvarchar strings", context do
      strs = [
        "hello",
        "'",
        "!@#$%^&*()",
        "Знакомства",
        ""
      ]

      Enum.each(strs, fn str ->
        assert [[str]] ==
                 query("SELECT @n1", [
                   %Parameter{name: "@n1", type: :string, value: str}
                 ])
      end)

      # Dates and Times
      # assert [{{{2014, 06, 20}, {10, 21, 42}}}] = query(
      # "SELECT @n1",
      # [%Parameter{name: "@n", value: {{2014, 06, 20}, {10, 21, 42}}])
    end
  end

  test "NULL Types", context do
    query("DROP TABLE TestTable", [])

    assert :ok =
             query(
               "CREATE TABLE TestTable (bin varbinary(1) NULL, uuid uniqueidentifier NULL, char nvarchar(1) NULL, nchar nvarchar(255) NULL)",
               []
             )

    sql = """
      INSERT INTO TestTable (bin) VALUES(@1)
    """

    params = [
      %Tds.Parameter{name: "@1", value: nil, type: :binary}
    ]

    assert :ok = query(sql, params)

    params = [
      %Tds.Parameter{name: "@1", value: nil, type: :uuid}
    ]

    assert :ok = query(sql, params)

    sql = """
      INSERT INTO TestTable (char) VALUES(@1)
    """

    params = [
      %Tds.Parameter{name: "@1", value: nil, type: :string}
    ]

    assert :ok = query(sql, params)

    sql = """
      INSERT INTO TestTable (nchar) VALUES(@1)
    """

    params = [
      %Tds.Parameter{name: "@1", value: nil, type: :string}
    ]

    assert :ok = query(sql, params)

    assert [[nil], [nil], [nil], [nil]] =
             query(
               "SELECT nchar FROM TestTable WHERE nchar IS NULL ORDER BY nchar",
               []
             )

    assert :ok = query("DROP TABLE dbo.TestTable", [])
  end

  test "Descriptors", context do
    assert [[1.0]] = query("SELECT @1", [%Parameter{name: "@1", value: 1.0}])
  end

  test "Char to binary encoding", context do
    query("DROP TABLE dbo.TestTable2", [])
    assert :ok = query("CREATE TABLE TestTable2 (text varbinary(max) NULL)", [])

    query("INSERT INTO TestTable2 VALUES (@1)", [
      %Parameter{name: "@1", value: "hello", type: :binary}
    ])

    assert [["hello"]] =
             query("SELECT * FROM TestTable2 WHERE text IN ('x', 'y', @1)", [
               %Parameter{name: "@1", value: "hello", type: :binary}
             ])
  end

  test "Common Types Null", context do
    query("DROP TABLE posts", [])

    assert :ok =
             query(
               """
               CREATE TABLE posts (
                 id bigint NOT NULL PRIMARY KEY IDENTITY,
                 title varchar(100) NULL,
                 counter integer DEFAULT 10 NULL,
                 text varchar(255) NULL,
                 tags nvarchar(max) NULL,
                 bin varbinary(255) NULL,
                 uuid uniqueidentifier NULL,
                 cost decimal(2,2) NULL,
                 inserted_at datetime NOT NULL,
                 updated_at datetime NOT NULL)
               """,
               []
             )

    sql = """
      INSERT INTO posts (
        bin,
        counter,
        inserted_at,
        tags,
        updated_at)  OUTPUT INSERTED.id , INSERTED.counter VALUES (
        @1,
        @2,
        @3,
        @4,
        @7
        )
    """

    params = [
      %Tds.Parameter{direction: :input, name: "@1", type: :binary, value: nil},
      %Tds.Parameter{direction: :input, name: "@2", type: :integer, value: nil},
      %Tds.Parameter{
        direction: :input,
        name: "@3",
        type: :datetime,
        value: {{2015, 2, 6}, {20, 30, 50, 0}}
      },
      %Tds.Parameter{
        direction: :input,
        name: "@4",
        type: {:array, :string},
        value: nil
      },
      # %Tds.Parameter{
      #   direction: :input, name: "@5", type: :string, value: nil},
      # %Tds.Parameter{
      # direction: :input, name: "@6", type: :string, value: nil},
      %Tds.Parameter{
        direction: :input,
        name: "@7",
        type: :datetime,
        value: {{2015, 2, 6}, {20, 30, 50, 0}}
      }
      # %Tds.Parameter{direction: :input, name: "@8", type: :uuid, value: nil}]
    ]

    assert [[1, nil]] = query(sql, params)
    assert :ok = query("DROP TABLE posts", [])
  end

  test "Inserting into params", context do
    query("DROP TABLE TestTable", [])

    assert :ok =
             query(
               "CREATE TABLE TestTable (TableId int, TableP1 varchar(20))",
               []
             )

    sql = """
      INSERT INTO TestTable (TableId, TableP1) VALUES(@id, @p1)
    """

    params = [
      %Tds.Parameter{name: "@id", value: 1234},
      %Tds.Parameter{name: "@p1", value: "secret"}
    ]

    assert :ok = query(sql, params)
    assert :ok = query("DROP TABLE dbo.TestTable", [])
  end

  test "read large table", context do
    pid = context[:pid]
    
    {:ok, res} = Tds.query(pid, "SELECT @1 as c1, @2 as c2", [
      %Tds.Parameter{name: "@1", value: "some string"},
      %Tds.Parameter{name: "@2", value: "some string", type: :binary}
    ])

    assert res.num_rows > 0
  end
end
