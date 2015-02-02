defmodule RPCTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  alias Tds.Connection, as: Conn
  alias Tds.Parameter

  @tag timeout: 50000

  setup do
    opts = [
      hostname: "sqlserver.local",
      port: 4000,
      username: "test_user",
      password: "passw0rd!",
      database: "test_db"
    ]
    {:ok, pid} = Conn.start_link(opts)
    {:ok, [pid: pid]}
  end

  test "Parameterized Queries", context do
    # Integers
    nums = [
      0,
      1,
      256,
      65536,
      4294967296
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

    # Strings
    strs = [
      "hello",
      "'",
      "!@#$%^&*()",
      "Знакомства",
      ""
    ]
    Enum.each(strs, fn(str) ->  
      assert [{str}] = query("SELECT @n1", [%Parameter{name: "@n1", value: str}])
    end)
    
    # Dates and Times
    #assert [{{{2014, 06, 20}, {10, 21, 42}}}] = query("SELECT @n1", [%Parameter{name: "@n", value: {{2014, 06, 20}, {10, 21, 42}}])
    
  end

  # test "Inserting into params", context do
  #   query("DROP TABLE TestTable", [])
  #   assert :ok = query("CREATE TABLE TestTable (TableId int, TableP1 varchar(20))", [])
  #   sql = """
  #     INSERT INTO TestTable (TableId, TableP1) VALUES(@id, @p1)
  #   """
  #   params = [
  #     %Tds.Parameter{name: "@id", value: 1234},
  #     %Tds.Parameter{name: "@p1", value: "secret"}
  #   ] 
  #   assert :ok = query(sql, params)
  #   assert :ok = query("DROP TABLE dbo.TestTable", [])
  # end

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