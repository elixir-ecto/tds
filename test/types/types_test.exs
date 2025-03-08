defmodule Tds.TypesTest do
  use ExUnit.Case, async: false

  alias Tds.Parameter

  import Tds.TestHelper

  require Logger

  @tds_data_type_decimaln 0x6A

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  defp create_table(context) do
    precision = context[:precision] || 10
    scale = context[:scale] || 4

    if not is_integer(precision) do
      raise ArgumentError, "precision must be an integer"
    end

    if not is_integer(scale) do
      raise ArgumentError, "scale must be an integer"
    end

    query("DROP TABLE IF EXISTS foo", [])
    query("CREATE TABLE foo (col DECIMAL(#{precision}, #{scale}) NOT NULL)", [])
  end

  defp insert_decimal(%Decimal{} = value, context) do
    query("TRUNCATE TABLE foo", [])

    :ok =
      query("INSERT INTO foo (col) VALUES (@1)", [
        %Parameter{name: "@1", value: value, type: :decimal}
      ])

    {:ok, result} = Tds.query(context[:pid], "SELECT col FROM foo", [])
    %Tds.Result{rows: [[value]]} = result
    value
  end

  describe "encode_data/3" do
    test "encodes decimal type", _context do
      value = Decimal.new("1000")
      attr = [precision: 8, scale: 4]

      # assert <<5, 1, 128, 150, 152, 0>> =
      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 1
      assert <<232, 3, 0, 0>> = value_binary
      assert :binary.decode_unsigned(value_binary, :little) == 1000
    end

    test "encodes decimal type with scientific notation", _context do
      value = Decimal.new("1E+3")
      attr = [precision: 8, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 1
      assert <<232, 3, 0, 0>> = value_binary
      assert :binary.decode_unsigned(value_binary, :little) == 1000
    end

    # Decimal.new("-1E+3")
    test "encodes negative decimal with scientific notation", _context do
      value = Decimal.new("-1E+3")
      attr = [precision: 8, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 0
      assert <<232, 3, 0, 0>> = value_binary
      assert :binary.decode_unsigned(value_binary, :little) == 1000
    end

    test "encodes decimal type with precision", _context do
      value = Decimal.new("1000.0000")
      attr = [precision: 8, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 1
      assert <<128, 150, 152, 0>> = value_binary
      assert :binary.decode_unsigned(value_binary, :little) == 10_000_000
    end

    test "encodes negative decimal", _context do
      value = Decimal.new("-1000.0000")
      attr = [precision: 8, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 0
      assert <<128, 150, 152, 0>> = value_binary
      assert :binary.decode_unsigned(value_binary, :little) == 10_000_000
    end

    test "encodes decimal type for 1000.1234", _context do
      value = Decimal.new("1000.1234")
      attr = [precision: 8, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 1
      assert <<82, 155, 152, 0>> = value_binary
      assert :binary.decode_unsigned(value_binary, :little) == 10_001_234
    end

    test "encodes very large decimal", _context do
      value = Decimal.new("9999999999.9999")
      attr = [precision: 14, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 9
      assert sign == 1
      assert :binary.decode_unsigned(value_binary, :little) == 99_999_999_999_999
    end

    test "encodes very small decimal", _context do
      value = Decimal.new("0.0001")
      attr = [precision: 5, scale: 4]

      assert <<byte_len>> <> <<sign>> <> value_binary =
               Tds.Types.encode_data(@tds_data_type_decimaln, value, attr)

      assert byte_len == 5
      assert sign == 1
      assert :binary.decode_unsigned(value_binary, :little) == 1
    end
  end

  describe "inserting decimal values into the database" do
    setup :create_table

    test "inserts various decimal values", context do
      assert insert_decimal(Decimal.new("1000"), context) == Decimal.new("1000.0000")
      assert insert_decimal(Decimal.new("1000.0000"), context) == Decimal.new("1000.0000")
      assert insert_decimal(Decimal.new("1000.1234"), context) == Decimal.new("1000.1234")
      assert insert_decimal(Decimal.new("-1000.0000"), context) == Decimal.new("-1000.0000")

      # Decimals can be scientific notation when converted from float:
      # iex> Decimal.from_float(1000.0)
      # Decimal.new("1E+3")
      assert insert_decimal(Decimal.new("1E+3"), context) == Decimal.new("1000.0000")
      assert insert_decimal(Decimal.new("-1E+3"), context) == Decimal.new("-1000.0000")
    end

    test "rounds decimals with more decimal places than column", context do
      assert insert_decimal(Decimal.new("1000.12345678"), context) == Decimal.new("1000.1235")
    end

    # Maximum precision and scale for SQL Server
    # https://learn.microsoft.com/en-us/sql/t-sql/data-types/precision-scale-and-length-transact-sql?view=sql-server-ver16#remarks
    @tag precision: 38, scale: 18
    test "inserts very large decimal", context do
      assert insert_decimal(Decimal.new("99999999999999999999.999999999999999999"), context) ==
               Decimal.new("99999999999999999999.999999999999999999")
    end

    test "inserts very small decimal", context do
      assert insert_decimal(Decimal.new("0.0001"), context) == Decimal.new("0.0001")
    end
  end
end
