defmodule Tds.Type.MoneyTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Money

  describe "type_codes/0" do
    test "returns money, smallmoney, and moneyn codes" do
      codes = Money.type_codes()
      # money (0x3C), smallmoney (0x7A), moneyn (0x6E)
      assert 0x3C in codes
      assert 0x7A in codes
      assert 0x6E in codes
      assert length(codes) == 3
    end
  end

  describe "type_names/0" do
    test "returns :money and :smallmoney" do
      assert Money.type_names() == [:money, :smallmoney]
    end
  end

  describe "decode_metadata/1" do
    test "fixed money (0x3C) returns {:fixed, 8}" do
      input = <<0x3C, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 8}}, <<0xAA, 0xBB>>} =
               Money.decode_metadata(input)
    end

    test "fixed smallmoney (0x7A) returns {:fixed, 4}" do
      input = <<0x7A, 0xCC, 0xDD>>

      assert {:ok, %{data_reader: {:fixed, 4}}, <<0xCC, 0xDD>>} =
               Money.decode_metadata(input)
    end

    test "variable moneyn (0x6E) reads 1-byte length" do
      input = <<0x6E, 0x08, 0xEE, 0xFF>>

      assert {:ok, %{data_reader: :bytelen, length: 8}, <<0xEE, 0xFF>>} =
               Money.decode_metadata(input)
    end

    test "variable moneyn (0x6E) with length 4" do
      input = <<0x6E, 0x04, 0xAA>>

      assert {:ok, %{data_reader: :bytelen, length: 4}, <<0xAA>>} =
               Money.decode_metadata(input)
    end
  end

  describe "decode/2 - nil" do
    test "nil returns nil" do
      assert Money.decode(nil, %{}) == nil
    end
  end

  describe "decode/2 - smallmoney (4 bytes)" do
    test "decodes 1.0000 (10000 units)" do
      data = <<0x10, 0x27, 0x00, 0x00>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("1.0000"))
    end

    test "decodes -1.0000 (-10000 units)" do
      data = <<0xF0, 0xD8, 0xFF, 0xFF>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("-1.0000"))
    end

    test "decodes zero" do
      data = <<0x00, 0x00, 0x00, 0x00>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("0.0000"))
    end

    test "decodes max smallmoney: 214748.3647" do
      # 214748.3647 * 10000 = 2147483647 = 0x7FFFFFFF
      data = <<0xFF, 0xFF, 0xFF, 0x7F>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("214748.3647"))
    end

    test "decodes min smallmoney: -214748.3648" do
      # -214748.3648 * 10000 = -2147483648 = 0x80000000
      data = <<0x00, 0x00, 0x00, 0x80>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("-214748.3648"))
    end

    test "decodes fractional: 0.0001" do
      data = <<0x01, 0x00, 0x00, 0x00>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("0.0001"))
    end

    test "decodes negative fractional: -0.0001" do
      data = <<0xFF, 0xFF, 0xFF, 0xFF>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("-0.0001"))
    end
  end

  describe "decode/2 - money (8 bytes)" do
    test "decodes 1.0000 (10000 units)" do
      # Money wire format: high 4 bytes (LE unsigned), low 4 bytes (LE unsigned)
      # 10000 = 0x00000000_00002710
      # high = 0x00000000 (LE: <<0,0,0,0>>), low = 0x00002710 (LE: <<0x10,0x27,0,0>>)
      data = <<0x00, 0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("1.0000"))
    end

    test "decodes -1.0000" do
      # -10000 as signed-64 = 0xFFFFFFFFFFFFD8F0
      # Split: high = 0xFFFFFFFF, low = 0xFFFFD8F0
      # high LE: <<0xFF,0xFF,0xFF,0xFF>>, low LE: <<0xF0,0xD8,0xFF,0xFF>>
      data = <<0xFF, 0xFF, 0xFF, 0xFF, 0xF0, 0xD8, 0xFF, 0xFF>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("-1.0000"))
    end

    test "decodes zero" do
      data = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("0.0000"))
    end

    test "decodes max money: 922337203685477.5807" do
      # 922337203685477.5807 * 10000 = 9223372036854775807 = 0x7FFFFFFFFFFFFFFF
      # high = 0x7FFFFFFF (LE: <<0xFF,0xFF,0xFF,0x7F>>)
      # low = 0xFFFFFFFF (LE: <<0xFF,0xFF,0xFF,0xFF>>)
      data = <<0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF>>
      result = Money.decode(data, %{})
      expected = Decimal.new("922337203685477.5807")
      assert Decimal.equal?(result, expected)
    end

    test "decodes min money: -922337203685477.5808" do
      # -922337203685477.5808 * 10000 = -9223372036854775808 = 0x8000000000000000
      # high = 0x80000000 (LE: <<0x00,0x00,0x00,0x80>>)
      # low = 0x00000000 (LE: <<0x00,0x00,0x00,0x00>>)
      data = <<0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00>>
      result = Money.decode(data, %{})
      expected = Decimal.new("-922337203685477.5808")
      assert Decimal.equal?(result, expected)
    end

    test "decodes a value spanning both high and low words" do
      # 1000000.0000 * 10000 = 10_000_000_000
      # 10_000_000_000 = 0x00000002_540BE400
      # high = 0x00000002 (LE: <<0x02,0x00,0x00,0x00>>)
      # low = 0x540BE400 (LE: <<0x00,0xE4,0x0B,0x54>>)
      data = <<0x02, 0x00, 0x00, 0x00, 0x00, 0xE4, 0x0B, 0x54>>
      result = Money.decode(data, %{})
      assert Decimal.equal?(result, Decimal.new("1000000.0000"))
    end
  end

  describe "encode/2" do
    test "nil produces moneyn null encoding" do
      {type_code, meta, value} = Money.encode(nil, %{})

      assert type_code == 0x6E
      assert IO.iodata_to_binary(meta) == <<0x08>>
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "Decimal.new(\"1.0000\") encodes as money (8-byte)" do
      dec = Decimal.new("1.0000")
      {type_code, meta, value} = Money.encode(dec, %{})

      assert type_code == 0x6E
      assert IO.iodata_to_binary(meta) == <<0x08>>

      value_bin = IO.iodata_to_binary(value)
      # length prefix + 8 bytes of money data
      <<0x08, high::little-unsigned-32, low::little-unsigned-32>> =
        value_bin

      <<combined::signed-64>> = <<high::32, low::32>>
      assert combined == 10_000
    end

    test "Decimal.new(\"-1.0000\") encodes negative money" do
      dec = Decimal.new("-1.0000")
      {type_code, _meta, value} = Money.encode(dec, %{})

      assert type_code == 0x6E
      value_bin = IO.iodata_to_binary(value)

      <<0x08, high::little-unsigned-32, low::little-unsigned-32>> =
        value_bin

      <<combined::signed-64>> = <<high::32, low::32>>
      assert combined == -10_000
    end

    test "Decimal.new(\"0\") encodes as zero" do
      dec = Decimal.new("0")
      {_type_code, _meta, value} = Money.encode(dec, %{})

      value_bin = IO.iodata_to_binary(value)

      <<0x08, high::little-unsigned-32, low::little-unsigned-32>> =
        value_bin

      <<combined::signed-64>> = <<high::32, low::32>>
      assert combined == 0
    end

    test "Decimal with fewer than 4 scale digits is scaled up" do
      dec = Decimal.new("1.5")
      {_type_code, _meta, value} = Money.encode(dec, %{})

      value_bin = IO.iodata_to_binary(value)

      <<0x08, high::little-unsigned-32, low::little-unsigned-32>> =
        value_bin

      <<combined::signed-64>> = <<high::32, low::32>>
      # 1.5 * 10000 = 15000
      assert combined == 15_000
    end
  end

  describe "param_descriptor/2" do
    test "smallmoney-range value returns smallmoney" do
      dec = Decimal.new("100.0000")
      assert Money.param_descriptor(dec, %{}) == "smallmoney"
    end

    test "nil returns money" do
      assert Money.param_descriptor(nil, %{}) == "money"
    end

    test "max smallmoney returns smallmoney" do
      dec = Decimal.new("214748.3647")
      assert Money.param_descriptor(dec, %{}) == "smallmoney"
    end

    test "min smallmoney returns smallmoney" do
      dec = Decimal.new("-214748.3648")
      assert Money.param_descriptor(dec, %{}) == "smallmoney"
    end

    test "value exceeding smallmoney range returns money" do
      dec = Decimal.new("214748.3648")
      assert Money.param_descriptor(dec, %{}) == "money"
    end

    test "large negative value returns money" do
      dec = Decimal.new("-214748.3649")
      assert Money.param_descriptor(dec, %{}) == "money"
    end

    test "large positive value returns money" do
      dec = Decimal.new("1000000.0000")
      assert Money.param_descriptor(dec, %{}) == "money"
    end
  end

  describe "infer/1" do
    test "always returns :skip (money is decode-only)" do
      assert :skip = Money.infer(Decimal.new("1.0"))
      assert :skip = Money.infer(42)
      assert :skip = Money.infer(nil)
      assert :skip = Money.infer("100.00")
    end
  end

  describe "encode/decode roundtrip" do
    test "Decimal.new(\"12345.6789\") roundtrips" do
      original = Decimal.new("12345.6789")
      {_type, _meta, value} = Money.encode(original, %{})
      value_bin = IO.iodata_to_binary(value)
      <<0x08, data::binary-8>> = value_bin

      decoded = Money.decode(data, %{})
      assert Decimal.equal?(decoded, original)
    end

    test "Decimal.new(\"-99999.9999\") roundtrips" do
      original = Decimal.new("-99999.9999")
      {_type, _meta, value} = Money.encode(original, %{})
      value_bin = IO.iodata_to_binary(value)
      <<0x08, data::binary-8>> = value_bin

      decoded = Money.decode(data, %{})
      assert Decimal.equal?(decoded, original)
    end

    test "zero roundtrips" do
      original = Decimal.new("0.0000")
      {_type, _meta, value} = Money.encode(original, %{})
      value_bin = IO.iodata_to_binary(value)
      <<0x08, data::binary-8>> = value_bin

      decoded = Money.decode(data, %{})
      assert Decimal.equal?(decoded, original)
    end
  end
end
