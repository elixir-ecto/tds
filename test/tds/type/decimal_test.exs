defmodule Tds.Type.DecimalTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Decimal, as: DecType

  describe "type_codes/0" do
    test "returns all four decimal/numeric type codes" do
      codes = DecType.type_codes()
      # decimal (0x37), numeric (0x3F), decimaln (0x6A), numericn (0x6C)
      assert 0x37 in codes
      assert 0x3F in codes
      assert 0x6A in codes
      assert 0x6C in codes
      assert length(codes) == 4
    end
  end

  describe "type_names/0" do
    test "returns :decimal" do
      assert DecType.type_names() == [:decimal]
    end
  end

  describe "decode_metadata/1" do
    test "decimaln (0x6A) reads length, precision, and scale" do
      # length=9, precision=18, scale=4, followed by tail bytes
      input = <<0x6A, 9, 18, 4, 0xAA, 0xBB>>

      assert {:ok, meta, <<0xAA, 0xBB>>} =
               DecType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.precision == 18
      assert meta.scale == 4
    end

    test "numericn (0x6C) reads length, precision, and scale" do
      input = <<0x6C, 17, 38, 18, 0xCC>>

      assert {:ok, meta, <<0xCC>>} =
               DecType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.precision == 38
      assert meta.scale == 18
    end

    test "legacy decimal (0x37) reads length byte" do
      input = <<0x37, 9, 0xDD>>

      assert {:ok, meta, <<0xDD>>} =
               DecType.decode_metadata(input)

      assert meta.data_reader == :bytelen
    end

    test "legacy numeric (0x3F) reads length byte" do
      input = <<0x3F, 9, 0xEE>>

      assert {:ok, meta, <<0xEE>>} =
               DecType.decode_metadata(input)

      assert meta.data_reader == :bytelen
    end
  end

  describe "decode/2" do
    test "nil returns nil" do
      assert DecType.decode(nil, %{precision: 10, scale: 4}) == nil
    end

    test "positive value: sign 0x01 with integer bytes" do
      # 10001234 as LE unsigned 4 bytes = Decimal.new("1000.1234")
      value_bytes = :binary.encode_unsigned(10_001_234, :little)
      data = <<0x01>> <> value_bytes
      meta = %{precision: 8, scale: 4}

      result = DecType.decode(data, meta)

      assert Decimal.equal?(result, Decimal.new("1000.1234"))
      assert result.sign == 1
    end

    test "negative value: sign 0x00 with integer bytes" do
      # 10000000 as LE unsigned 4 bytes = Decimal.new("-1000.0000")
      value_bytes = :binary.encode_unsigned(10_000_000, :little)
      data = <<0x00>> <> value_bytes
      meta = %{precision: 8, scale: 4}

      result = DecType.decode(data, meta)

      assert Decimal.equal?(result, Decimal.new("-1000.0000"))
      assert result.sign == -1
    end

    test "zero decodes correctly" do
      # Zero coefficient, positive sign
      data = <<0x01, 0x00, 0x00, 0x00, 0x00>>
      meta = %{precision: 10, scale: 4}

      result = DecType.decode(data, meta)

      assert Decimal.equal?(result, Decimal.new("0.0000"))
    end

    test "decodes value matching existing test vector: 1000" do
      # From types_test.exs: value=1000, coef=1000
      value_bytes = <<232, 3, 0, 0>>
      data = <<0x01>> <> value_bytes
      meta = %{precision: 8, scale: 0}

      result = DecType.decode(data, meta)

      assert Decimal.equal?(result, Decimal.new("1000"))
    end

    test "decodes 99999.99999 with precision 10, scale 5" do
      # 9999999999 as LE
      value_bytes = :binary.encode_unsigned(9_999_999_999, :little)
      data = <<0x01>> <> value_bytes
      meta = %{precision: 10, scale: 5}

      result = DecType.decode(data, meta)

      assert Decimal.equal?(result, Decimal.new("99999.99999"))
    end

    test "decodes max precision (38 digits)" do
      max_val = 99_999_999_999_999_999_999_999_999_999_999_999_999
      value_bytes = :binary.encode_unsigned(max_val, :little)
      data = <<0x01>> <> value_bytes
      meta = %{precision: 38, scale: 0}

      result = DecType.decode(data, meta)

      expected = Decimal.new("99999999999999999999999999999999999999")
      assert Decimal.equal?(result, expected)
    end

    test "does not mutate process dictionary precision" do
      precision_before = Decimal.Context.get().precision

      value_bytes = :binary.encode_unsigned(12345, :little)
      data = <<0x01>> <> value_bytes
      meta = %{precision: 38, scale: 2}
      DecType.decode(data, meta)

      assert Decimal.Context.get().precision == precision_before
    end
  end

  describe "encode/2" do
    test "nil produces decimaln null encoding" do
      {type_code, meta, value} = DecType.encode(nil, %{})

      assert type_code == 0x6A
      assert IO.iodata_to_binary(meta) == <<0x6A, 0x01, 0x01, 0x00>>
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "Decimal.new(\"12345.6789\") encodes correctly" do
      dec = Decimal.new("12345.6789")
      {type_code, meta_bin, value_bin} = DecType.encode(dec, %{})

      assert type_code == 0x6A

      meta = IO.iodata_to_binary(meta_bin)
      # type(0x6A) + value_size + precision(9) + scale(4)
      <<0x6A, value_size, precision, scale>> = meta
      assert precision == 9
      assert scale == 4

      value = IO.iodata_to_binary(value_bin)
      # byte_len + sign + LE value
      <<byte_len, sign, rest::binary>> = value
      assert byte_len == value_size
      assert sign == 1

      int_val =
        rest
        |> :binary.bin_to_list()
        |> Enum.reject(&(&1 == 0))
        |> :binary.list_to_bin()
        |> :binary.decode_unsigned(:little)

      assert int_val == 123_456_789
    end

    test "Decimal.new(\"0\") encodes zero" do
      dec = Decimal.new("0")
      {type_code, meta_bin, value_bin} = DecType.encode(dec, %{})

      assert type_code == 0x6A

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, precision, scale>> = meta
      assert precision == 1
      assert scale == 0

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, sign, _rest::binary>> = value
      assert sign == 1
    end

    test "Decimal.new(\"-123.45\") encodes with correct sign" do
      dec = Decimal.new("-123.45")
      {type_code, _meta_bin, value_bin} = DecType.encode(dec, %{})

      assert type_code == 0x6A

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, sign, rest::binary>> = value
      assert sign == 0

      int_val =
        rest
        |> :binary.bin_to_list()
        |> Enum.reject(&(&1 == 0))
        |> :binary.list_to_bin()
        |> :binary.decode_unsigned(:little)

      assert int_val == 12345
    end

    test "scientific notation Decimal.new(\"1E+3\") handled correctly" do
      dec = Decimal.new("1E+3")
      {type_code, meta_bin, value_bin} = DecType.encode(dec, %{})

      assert type_code == 0x6A

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, precision, scale>> = meta
      assert precision == 4
      assert scale == 0

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, sign, rest::binary>> = value
      assert sign == 1

      int_val =
        rest
        |> :binary.bin_to_list()
        |> Enum.reject(&(&1 == 0))
        |> :binary.list_to_bin()
        |> :binary.decode_unsigned(:little)

      assert int_val == 1000
    end

    test "does not mutate process dictionary precision" do
      precision_before = Decimal.Context.get().precision

      dec = Decimal.new("12345.6789")
      DecType.encode(dec, %{})

      assert Decimal.Context.get().precision == precision_before
    end
  end

  describe "param_descriptor/2" do
    test "nil returns decimal(1, 0)" do
      assert DecType.param_descriptor(nil, %{}) == "decimal(1, 0)"
    end

    test "Decimal with fractional part returns correct precision/scale" do
      dec = Decimal.new("12345.6789")
      assert DecType.param_descriptor(dec, %{}) == "decimal(9, 4)"
    end

    test "Decimal without fractional part returns scale 0" do
      dec = Decimal.new("1000")
      assert DecType.param_descriptor(dec, %{}) == "decimal(4, 0)"
    end

    test "scientific notation Decimal returns correct descriptor" do
      dec = Decimal.new("1E+3")
      assert DecType.param_descriptor(dec, %{}) == "decimal(4, 0)"
    end

    test "negative Decimal returns correct descriptor" do
      dec = Decimal.new("-123.45")
      assert DecType.param_descriptor(dec, %{}) == "decimal(5, 2)"
    end

    test "zero returns decimal(1, 0)" do
      dec = Decimal.new("0")
      assert DecType.param_descriptor(dec, %{}) == "decimal(1, 0)"
    end

    test "max precision returns decimal(38, 0)" do
      dec = Decimal.new("99999999999999999999999999999999999999")
      assert DecType.param_descriptor(dec, %{}) == "decimal(38, 0)"
    end
  end

  describe "infer/1" do
    test "Decimal struct infers" do
      assert {:ok, %{}} = DecType.infer(Decimal.new("42.5"))
    end

    test "Decimal zero infers" do
      assert {:ok, %{}} = DecType.infer(Decimal.new("0"))
    end

    test "integer skips" do
      assert :skip = DecType.infer(42)
    end

    test "float skips" do
      assert :skip = DecType.infer(3.14)
    end

    test "string skips" do
      assert :skip = DecType.infer("42.5")
    end

    test "nil skips" do
      assert :skip = DecType.infer(nil)
    end
  end

  describe "encode/decode roundtrip" do
    test "Decimal.new(\"1000.1234\") roundtrips" do
      original = Decimal.new("1000.1234")
      {_type, meta_bin, value_bin} = DecType.encode(original, %{})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, precision, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      # Strip the byte_len prefix to get the raw data
      <<_byte_len, data::binary>> = value

      decoded = DecType.decode(data, %{precision: precision, scale: scale})
      assert Decimal.equal?(decoded, original)
    end

    test "Decimal.new(\"-99999.99999\") roundtrips" do
      original = Decimal.new("-99999.99999")
      {_type, meta_bin, value_bin} = DecType.encode(original, %{})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, precision, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, data::binary>> = value

      decoded = DecType.decode(data, %{precision: precision, scale: scale})
      assert Decimal.equal?(decoded, original)
    end

    test "Decimal.new(\"1E+3\") roundtrips" do
      original = Decimal.new("1E+3")
      {_type, meta_bin, value_bin} = DecType.encode(original, %{})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, precision, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, data::binary>> = value

      decoded = DecType.decode(data, %{precision: precision, scale: scale})
      # 1E+3 normalizes to 1000
      assert Decimal.equal?(decoded, Decimal.new("1000"))
    end

    test "Decimal.new(\"0.0001\") roundtrips" do
      original = Decimal.new("0.0001")
      {_type, meta_bin, value_bin} = DecType.encode(original, %{})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, precision, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, data::binary>> = value

      decoded = DecType.decode(data, %{precision: precision, scale: scale})
      assert Decimal.equal?(decoded, original)
    end

    test "process dictionary unchanged after roundtrip" do
      precision_before = Decimal.Context.get().precision

      original = Decimal.new("12345.6789")
      {_type, meta_bin, value_bin} = DecType.encode(original, %{})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x6A, _value_size, p, s>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_byte_len, data::binary>> = value
      DecType.decode(data, %{precision: p, scale: s})

      assert Decimal.Context.get().precision == precision_before
    end
  end
end
