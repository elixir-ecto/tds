defmodule Tds.Type.IntegerTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Integer

  describe "type_codes/0" do
    test "returns all five integer type codes" do
      codes = Integer.type_codes()
      assert 0x30 in codes
      assert 0x34 in codes
      assert 0x38 in codes
      assert 0x7F in codes
      assert 0x26 in codes
      assert length(codes) == 5
    end
  end

  describe "type_names/0" do
    test "returns :integer" do
      assert Integer.type_names() == [:integer]
    end
  end

  describe "decode_metadata/1" do
    test "tinyint (0x30) is fixed 1 byte" do
      input = <<0x30, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 1}}, <<0xAA, 0xBB>>} =
               Integer.decode_metadata(input)
    end

    test "smallint (0x34) is fixed 2 bytes" do
      input = <<0x34, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 2}}, <<0xAA, 0xBB>>} =
               Integer.decode_metadata(input)
    end

    test "int (0x38) is fixed 4 bytes" do
      input = <<0x38, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 4}}, <<0xAA, 0xBB>>} =
               Integer.decode_metadata(input)
    end

    test "bigint (0x7F) is fixed 8 bytes" do
      input = <<0x7F, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 8}}, <<0xAA, 0xBB>>} =
               Integer.decode_metadata(input)
    end

    test "intn (0x26) reads 1-byte length" do
      input = <<0x26, 0x04, 0xCC, 0xDD>>

      assert {:ok, %{data_reader: :bytelen, length: 4}, <<0xCC, 0xDD>>} =
               Integer.decode_metadata(input)
    end

    test "intn (0x26) with length 8" do
      input = <<0x26, 0x08, 0xEE>>

      assert {:ok, %{data_reader: :bytelen, length: 8}, <<0xEE>>} =
               Integer.decode_metadata(input)
    end

    test "intn (0x26) with length 1" do
      input = <<0x26, 0x01, 0xFF>>

      assert {:ok, %{data_reader: :bytelen, length: 1}, <<0xFF>>} =
               Integer.decode_metadata(input)
    end

    test "intn (0x26) with length 2" do
      input = <<0x26, 0x02, 0xFF>>

      assert {:ok, %{data_reader: :bytelen, length: 2}, <<0xFF>>} =
               Integer.decode_metadata(input)
    end
  end

  describe "decode/2" do
    test "nil returns nil" do
      assert Integer.decode(nil, %{}) == nil
    end

    test "1-byte unsigned tinyint" do
      assert Integer.decode(<<42>>, %{length: 1}) == 42
    end

    test "1-byte unsigned tinyint max value" do
      assert Integer.decode(<<255>>, %{length: 1}) == 255
    end

    test "2-byte little-endian signed smallint" do
      assert Integer.decode(<<0xD2, 0x04>>, %{length: 2}) == 1234
    end

    test "2-byte negative smallint" do
      assert Integer.decode(<<0xFE, 0xFF>>, %{length: 2}) == -2
    end

    test "2-byte smallint -1" do
      assert Integer.decode(<<0xFF, 0xFF>>, %{length: 2}) == -1
    end

    test "4-byte little-endian signed int" do
      assert Integer.decode(<<42, 0, 0, 0>>, %{length: 4}) == 42
    end

    test "4-byte negative int" do
      assert Integer.decode(<<0xFE, 0xFF, 0xFF, 0xFF>>, %{length: 4}) == -2
    end

    test "4-byte int max positive" do
      # 2_147_483_647 = 0x7FFFFFFF
      assert Integer.decode(
               <<0xFF, 0xFF, 0xFF, 0x7F>>,
               %{length: 4}
             ) == 2_147_483_647
    end

    test "8-byte little-endian signed bigint" do
      assert Integer.decode(
               <<42, 0, 0, 0, 0, 0, 0, 0>>,
               %{length: 8}
             ) == 42
    end

    test "8-byte negative bigint" do
      assert Integer.decode(
               <<0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>,
               %{length: 8}
             ) == -2
    end

    test "8-byte large bigint" do
      # 1_000_000_000_000 = 0xE8D4A51000
      assert Integer.decode(
               <<0x00, 0x10, 0xA5, 0xD4, 0xE8, 0x00, 0x00, 0x00>>,
               %{length: 8}
             ) == 1_000_000_000_000
    end

    test "decode without explicit length uses data size" do
      assert Integer.decode(<<42>>, %{}) == 42
      assert Integer.decode(<<0xD2, 0x04>>, %{}) == 1234
      assert Integer.decode(<<42, 0, 0, 0>>, %{}) == 42

      assert Integer.decode(
               <<42, 0, 0, 0, 0, 0, 0, 0>>,
               %{}
             ) == 42
    end
  end

  describe "encode/2" do
    test "nil produces intn null encoding" do
      {type_code, meta, value} = Integer.encode(nil, %{})

      assert type_code == 0x26
      assert IO.iodata_to_binary(meta) == <<0x26, 0x04>>
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "small positive integer encodes as 4-byte intn" do
      {type_code, meta, value} = Integer.encode(42, %{})

      assert type_code == 0x26
      assert IO.iodata_to_binary(meta) == <<0x26, 0x04>>

      assert IO.iodata_to_binary(value) ==
               <<0x04, 42, 0, 0, 0>>
    end

    test "zero encodes as 4-byte intn" do
      {type_code, meta, value} = Integer.encode(0, %{})

      assert type_code == 0x26
      assert IO.iodata_to_binary(meta) == <<0x26, 0x04>>

      assert IO.iodata_to_binary(value) ==
               <<0x04, 0, 0, 0, 0>>
    end

    test "negative integer encodes as 4-byte signed" do
      {type_code, meta, value} = Integer.encode(-2, %{})

      assert type_code == 0x26
      assert IO.iodata_to_binary(meta) == <<0x26, 0x04>>

      assert IO.iodata_to_binary(value) ==
               <<0x04, 0xFE, 0xFF, 0xFF, 0xFF>>
    end

    test "large positive encodes as 8-byte bigint" do
      big = 3_000_000_000

      {type_code, meta, value} = Integer.encode(big, %{})

      assert type_code == 0x26
      assert IO.iodata_to_binary(meta) == <<0x26, 0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, big::little-signed-64>>
    end

    test "max int32 boundary stays 4-byte" do
      max_int32 = 2_147_483_647

      {_type_code, meta, value} =
        Integer.encode(max_int32, %{})

      assert IO.iodata_to_binary(meta) == <<0x26, 0x04>>

      assert IO.iodata_to_binary(value) ==
               <<0x04, max_int32::little-signed-32>>
    end

    test "min int32 boundary stays 4-byte" do
      min_int32 = -2_147_483_648

      {_type_code, meta, value} =
        Integer.encode(min_int32, %{})

      assert IO.iodata_to_binary(meta) == <<0x26, 0x04>>

      assert IO.iodata_to_binary(value) ==
               <<0x04, min_int32::little-signed-32>>
    end

    test "above int32 max uses 8-byte" do
      val = 2_147_483_648

      {_type_code, meta, value} = Integer.encode(val, %{})

      assert IO.iodata_to_binary(meta) == <<0x26, 0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, val::little-signed-64>>
    end

    test "below int32 min uses 8-byte" do
      val = -2_147_483_649

      {_type_code, meta, value} = Integer.encode(val, %{})

      assert IO.iodata_to_binary(meta) == <<0x26, 0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, val::little-signed-64>>
    end
  end

  describe "param_descriptor/2" do
    test "zero returns int" do
      assert Integer.param_descriptor(0, %{}) == "int"
    end

    test "positive returns bigint" do
      assert Integer.param_descriptor(42, %{}) == "bigint"
      assert Integer.param_descriptor(1, %{}) == "bigint"
    end

    test "negative returns decimal(N, 0)" do
      # -2 has string "-2", length 2, precision = 2 - 1 = 1
      assert Integer.param_descriptor(-2, %{}) == "decimal(1, 0)"
    end

    test "larger negative returns decimal with correct precision" do
      # -1000 has string "-1000", length 5, precision = 5 - 1 = 4
      assert Integer.param_descriptor(-1000, %{}) ==
               "decimal(4, 0)"
    end

    test "nil returns int" do
      assert Integer.param_descriptor(nil, %{}) == "int"
    end
  end

  describe "infer/1" do
    test "integer value infers" do
      assert {:ok, %{}} = Integer.infer(42)
    end

    test "zero infers" do
      assert {:ok, %{}} = Integer.infer(0)
    end

    test "negative integer infers" do
      assert {:ok, %{}} = Integer.infer(-5)
    end

    test "float skips" do
      assert :skip = Integer.infer(3.14)
    end

    test "string skips" do
      assert :skip = Integer.infer("42")
    end

    test "boolean skips" do
      assert :skip = Integer.infer(true)
    end

    test "nil skips" do
      assert :skip = Integer.infer(nil)
    end
  end
end
