defmodule RPCTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case
  alias Tds.Connection, as: Conn
  alias Tds.Parameter

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

  test "Parameterized Queries", context do
    Integers
    nums = [
      0,
      1,
      256,
      65536,
      4294967296,
      20080906120000
    ]
    Enum.each(nums, fn(num) ->  
      assert [{num}] = query("SELECT @n1", [%Parameter{name: "@n1", value: num}])
    end)

    # Negative Numbers
    nums = [
      -111111111,
      -1111111111111111111,
      -1111111111111111111111111111,
      -11111111111111111111111111111111111111
    ]
    Enum.each(nums, fn(num) ->  
      assert [{num}] = query("SELECT @n1", [%Parameter{name: "@n1", value: num}])
    end)

    # Decimals
    nums = [
      Decimal.new("1.11111111"),
      Decimal.new("1.111111111111111111"),
      Decimal.new("1.111111111111111111111111111"),
      Decimal.new("1.1111111111111111111111111111111111111")
    ]
    Enum.each(nums, fn(num) ->  
      assert [{num}] = query("SELECT @n1", [%Parameter{name: "@n1", value: num}])
    end)

    # VarChar Strings
    strs = [
      "hello",
      "'",
      "!@#$%^&*()",
      ""
    ]
    Enum.each(strs, fn(str) ->  
      assert [{str}] = query("SELECT @n1", [%Parameter{name: "@n1", value: str}])
    end)

    strs = [
      "hello",
      "'",
      "!@#$%^&*()",
      "Знакомства",
      ""
    ]
    Enum.each(strs, fn(str) ->  
      assert [{str}] = query("SELECT @n1", [%Parameter{name: "@n1", type: :string, value: str}])
    end)
    
    # Dates and Times
    #assert [{{{2014, 06, 20}, {10, 21, 42}}}] = query("SELECT @n1", [%Parameter{name: "@n", value: {{2014, 06, 20}, {10, 21, 42}}])
    
  end

  test "NULL Types", context do
    query("DROP TABLE TestTable", [])
    assert :ok = query("CREATE TABLE TestTable (bin varbinary(1) NULL, uuid uniqueidentifier NULL, char nvarchar(1) NULL, nchar nvarchar(255) NULL)", [])
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
    #assert [{nil}, {nil}, {nil}] = query("SELECT nchar FROM TestTable WHERE nchar IS NULL ORDER BY nchar", [])
    assert :ok = query("DROP TABLE dbo.TestTable", [])
  end

  # test "Descriptors", context do
  #   assert [{1.0}] = query("SELECT @1", [%Parameter{name: "@1", value: 1.0}])
  # end

  test "Char to binary encoding", context do
    query("DROP TABLE dbo.TestTable2", [])
    assert :ok = query("CREATE TABLE TestTable2 (text varbinary(max) NULL)", [])
    query("INSERT INTO TestTable2 VALUES (@1)",[%Parameter{name: "@1", value: "hello", type: :binary}])
    assert [{"hello"}] = query("SELECT * FROM TestTable2 WHERE text IN ('x', 'y', @1)", [%Parameter{name: "@1", value: "hello"}])
  end

  test "Common Types Null", context do
    query("DROP TABLE posts", [])
    assert :ok = query("""
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
      """, [])
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
      %Tds.Parameter{direction: :input, name: "@3", type: :datetime, value: {{2015, 2, 6}, {20, 30, 50, 0}}},
      %Tds.Parameter{direction: :input, name: "@4", type: {:array, :string}, value: nil},
      # %Tds.Parameter{direction: :input, name: "@5", type: :string, value: nil},
      # %Tds.Parameter{direction: :input, name: "@6", type: :string, value: nil},
      %Tds.Parameter{direction: :input, name: "@7", type: :datetime, value: {{2015, 2, 6}, {20, 30, 50, 0}}},
      # %Tds.Parameter{direction: :input, name: "@8", type: :uuid, value: nil}]
    ] 
    assert [{1, nil}] = query(sql, params)
    assert :ok = query("DROP TABLE posts", [])
  end

  test "Inserting into params", context do
    query("DROP TABLE TestTable", [])
    assert :ok = query("CREATE TABLE TestTable (TableId int, TableP1 varchar(20))", [])
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

  # test "Stored procedure", context do
  #   q = """
  #     CREATE PROCEDURE testproc (@param int, @add int = 2, @outparam int output)
  #       AS
  #       BEGIN
  #           SET nocount ON
  #           SET @outparam = @param + @add
  #           RETURN @outparam
  #       END
  #   """
  #   value = 45
  #   assert :ok =  query(q, [])
  #   assert [{47}] = proc("testproc", [{val}, {:default}, {:output, 1}])
  # end

end
