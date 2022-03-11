defmodule DecimalTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Parameter

  @tag timeout: 50000

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  describe "database" do
    test "decimal overflow", context do
      table_name = "decimal_overflow_test"

      query("DROP TABLE #{table_name}", [])

      :ok =
        query(
          """
            CREATE TABLE #{table_name} (
              one_one decimal(1, 1) NULL
              )
          """,
          []
        )

      p = %Parameter{
        name: "@1",
        value: Decimal.new("1337.4711"),
        type: :decimal
      }

      assert %Tds.Error{mssql: %{msg_text: msg_text}} =
               "INSERT INTO #{table_name} VALUES (@1)"
               |> query([p])

      assert msg_text =~ "Arithmetic overflow"

      query("DROP TABLE #{table_name}", [])
    end

    test "insert decimals", context do
      table_name = "decimal_test"
      query("DROP TABLE #{table_name}", [])

      :ok =
        query(
          """
            CREATE TABLE #{table_name} (
              ten_five decimal(10, 5) NULL,
              ver int NOT NULL
              )
          """,
          []
        )

      version = %Parameter{name: "@2", value: 1, type: :integer}

      assert :ok =
               "INSERT INTO #{table_name} VALUES (@1, @2)"
               |> query([
                 %Parameter{name: "@1", value: nil, type: :decimal},
                 version
               ])

      assert [[nil]] == query("SELECT ten_five from #{table_name} WHERE ver = 1")

      p = %Parameter{
        name: "@1",
        value: Decimal.new("1757.00000"),
        type: :decimal
      }

      assert :ok =
               "INSERT INTO #{table_name} VALUES (@1, @2)"
               |> query([p, %{version | value: 2}])

      assert [[Decimal.new("1757.00000")]] ==
               query("SELECT ten_five from #{table_name} WHERE ver = 2")

      query("DROP TABLE #{table_name}", [])
    end

    test "insert decimal with losing precision", context do
      table_name = "decimal_with_losing_precision_test"
      query("DROP TABLE #{table_name}", [])

      :ok =
        query(
          """
            CREATE TABLE #{table_name} (
              ten_one decimal(10, 1) NULL,
              ver int NOT NULL
              )
          """,
          []
        )

      version = %Parameter{name: "@2", value: 1, type: :integer}

      assert :ok =
               "INSERT INTO #{table_name} VALUES (@1, @2)"
               |> query([
                 %Parameter{name: "@1", value: nil, type: :decimal},
                 version
               ])

      assert [[nil]] == query("SELECT ten_one from #{table_name} WHERE ver = 1")

      p = %Parameter{
        name: "@1",
        value: Decimal.new("1757.4711"),
        type: :decimal
      }

      assert :ok =
               "INSERT INTO #{table_name} VALUES (@1, @2)"
               |> query([p, %{version | value: 2}])

      assert [[Decimal.new("1757.5")]] ==
               query("SELECT ten_one from #{table_name} WHERE ver = 2")

      query("DROP TABLE #{table_name}", [])
    end
  end
end
