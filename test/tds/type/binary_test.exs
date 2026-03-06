defmodule Tds.Type.BinaryTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Binary, as: BinType
  alias Tds.Encoding.UCS2

  describe "type_codes/0" do
    test "returns all 5 binary-related type codes" do
      codes = BinType.type_codes()

      assert 0xAD in codes  # bigbinary
      assert 0xA5 in codes  # bigvarbinary
      assert 0x22 in codes  # image
      assert 0x2D in codes  # legacy binary
      assert 0x25 in codes  # legacy varbinary
      assert length(codes) == 5
    end
  end

  describe "type_names/0" do
    test "returns :binary and :image" do
      assert BinType.type_names() == [:binary, :image]
    end
  end

  # -- decode_metadata -----------------------------------------------

  describe "decode_metadata/1 for bigbinary (0xAD)" do
    test "reads 2-byte LE max_length, shortlen reader" do
      tail = <<0xAA, 0xBB>>
      input = <<0xAD, 200::little-unsigned-16>> <> tail

      assert {:ok, meta, ^tail} = BinType.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.length == 200
    end

    test "PLP marker 0xFFFF sets data_reader to :plp" do
      input = <<0xAD, 0xFF, 0xFF, 0xCC>>

      assert {:ok, meta, <<0xCC>>} = BinType.decode_metadata(input)
      assert meta.data_reader == :plp
    end
  end

  describe "decode_metadata/1 for bigvarbinary (0xA5)" do
    test "reads 2-byte LE max_length, shortlen reader" do
      tail = <<0xDD>>
      input = <<0xA5, 4000::little-unsigned-16>> <> tail

      assert {:ok, meta, ^tail} = BinType.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.length == 4000
    end

    test "PLP marker 0xFFFF sets data_reader to :plp" do
      input = <<0xA5, 0xFF, 0xFF, 0xEE>>

      assert {:ok, meta, <<0xEE>>} = BinType.decode_metadata(input)
      assert meta.data_reader == :plp
    end
  end

  describe "decode_metadata/1 for legacy binary (0x2D)" do
    test "reads 1-byte length, bytelen reader" do
      tail = <<0x11, 0x22>>
      input = <<0x2D, 100>> <> tail

      assert {:ok, meta, ^tail} = BinType.decode_metadata(input)
      assert meta.data_reader == :bytelen
      assert meta.length == 100
    end
  end

  describe "decode_metadata/1 for legacy varbinary (0x25)" do
    test "reads 1-byte length, bytelen reader" do
      tail = <<0x33>>
      input = <<0x25, 50>> <> tail

      assert {:ok, meta, ^tail} = BinType.decode_metadata(input)
      assert meta.data_reader == :bytelen
      assert meta.length == 50
    end
  end

  describe "decode_metadata/1 for image (0x22)" do
    test "reads 4-byte length and table name parts" do
      table_name = UCS2.from_string("imgs")
      table_size = div(byte_size(table_name), 2)
      tail = <<0x44>>

      input =
        <<0x22, 2_147_483_647::little-unsigned-32,
          1::signed-8, table_size::little-unsigned-16>> <>
          table_name <> tail

      assert {:ok, meta, ^tail} = BinType.decode_metadata(input)
      assert meta.data_reader == :longlen
      assert meta.length == 2_147_483_647
    end

    test "reads multiple table name parts" do
      t1 = UCS2.from_string("dbo")
      t1_size = div(byte_size(t1), 2)
      t2 = UCS2.from_string("tbl")
      t2_size = div(byte_size(t2), 2)
      tail = <<0x55>>

      input =
        <<0x22, 100::little-unsigned-32, 2::signed-8,
          t1_size::little-unsigned-16>> <>
          t1 <>
          <<t2_size::little-unsigned-16>> <>
          t2 <> tail

      assert {:ok, meta, ^tail} = BinType.decode_metadata(input)
      assert meta.data_reader == :longlen
    end
  end

  # -- decode ---------------------------------------------------------

  describe "decode/2" do
    test "nil returns nil" do
      assert BinType.decode(nil, %{}) == nil
    end

    test "raw binary passthrough, no character conversion" do
      data = <<0x00, 0x01, 0xFF, 0xFE, 0x80, 0x7F>>
      result = BinType.decode(data, %{})
      assert result == data
    end

    test "returns independent copy of the data" do
      # Ensure returned binary is not a sub-binary reference
      big = :crypto.strong_rand_bytes(100)
      <<chunk::binary-size(10), _rest::binary>> = big
      result = BinType.decode(chunk, %{})
      assert result == chunk
      assert byte_size(result) == 10
    end

    test "empty binary returns empty binary" do
      assert BinType.decode(<<>>, %{}) == <<>>
    end

    test "preserves arbitrary bytes including invalid UTF-8" do
      data = <<0xC0, 0xC1, 0xF5, 0xFF>>
      assert BinType.decode(data, %{}) == data
    end
  end

  # -- encode ---------------------------------------------------------

  describe "encode/2" do
    test "nil produces bigvarbinary PLP null" do
      {type_code, meta_bin, value_bin} = BinType.encode(nil, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 0xFF, 0xFF>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0xFFFFFFFFFFFFFFFF::little-unsigned-64>>
    end

    test "short binary uses shortlen format" do
      data = <<1, 2, 3, 4, 5>>
      {type_code, meta_bin, value_bin} = BinType.encode(data, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 5::little-unsigned-16>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<5::little-unsigned-16, 1, 2, 3, 4, 5>>
    end

    test "empty binary encodes as PLP empty" do
      {type_code, meta_bin, value_bin} = BinType.encode(<<>>, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 0xFF, 0xFF>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0::unsigned-64, 0::unsigned-32>>
    end

    test "large binary (> 8000 bytes) uses PLP format" do
      data = :crypto.strong_rand_bytes(8001)
      {type_code, meta_bin, value_bin} = BinType.encode(data, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 0xFF, 0xFF>>

      value = IO.iodata_to_binary(value_bin)
      <<total_size::little-unsigned-64, _rest::binary>> = value
      assert total_size == 8001

      # Ends with PLP terminator
      assert :binary.part(value, byte_size(value), -4) ==
               <<0::little-unsigned-32>>
    end

    test "exactly 8000 bytes uses shortlen" do
      data = :crypto.strong_rand_bytes(8000)
      {_type_code, meta_bin, _value_bin} = BinType.encode(data, %{})

      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 8000::little-unsigned-16>>
    end

    test "integer value is coerced to single byte" do
      {type_code, meta_bin, value_bin} = BinType.encode(42, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 1::little-unsigned-16>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<1::little-unsigned-16, 42>>
    end
  end

  # -- param_descriptor -----------------------------------------------

  describe "param_descriptor/2" do
    test "nil returns varbinary(1)" do
      assert BinType.param_descriptor(nil, %{}) == "varbinary(1)"
    end

    test "empty binary returns varbinary(1)" do
      assert BinType.param_descriptor(<<>>, %{}) == "varbinary(1)"
    end

    test "non-empty binary returns varbinary(max)" do
      data = <<1, 2, 3>>
      assert BinType.param_descriptor(data, %{}) == "varbinary(max)"
    end

    test "large binary returns varbinary(max)" do
      data = :crypto.strong_rand_bytes(9000)
      assert BinType.param_descriptor(data, %{}) == "varbinary(max)"
    end

    test "integer value is coerced" do
      assert BinType.param_descriptor(42, %{}) == "varbinary(max)"
    end
  end

  # -- infer ----------------------------------------------------------

  describe "infer/1" do
    test "invalid UTF-8 binary infers as binary" do
      assert {:ok, %{}} = BinType.infer(<<0xC0, 0xC1, 0xF5>>)
    end

    test "nil skips" do
      assert :skip = BinType.infer(nil)
    end

    test "valid UTF-8 string skips (string handler takes those)" do
      assert :skip = BinType.infer("hello")
    end

    test "empty string skips (string handler takes those)" do
      assert :skip = BinType.infer("")
    end

    test "integer skips" do
      assert :skip = BinType.infer(42)
    end

    test "atom skips" do
      assert :skip = BinType.infer(:foo)
    end
  end

  # -- roundtrip ------------------------------------------------------

  describe "encode/decode roundtrip" do
    test "short binary roundtrips" do
      original = <<0xDE, 0xAD, 0xBE, 0xEF>>
      {_type, _meta, value_bin} = BinType.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      # shortlen: 2-byte length prefix + raw data
      <<size::little-unsigned-16, data::binary-size(size)>> = value

      assert BinType.decode(data, %{}) == original
    end

    test "large binary roundtrips through PLP" do
      original = :crypto.strong_rand_bytes(10_000)
      {_type, _meta, value_bin} = BinType.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      # PLP: skip 8-byte total size, then reassemble chunks
      <<_total::little-unsigned-64, chunked::binary>> = value
      data = reassemble_plp(chunked)

      assert BinType.decode(data, %{}) == original
    end
  end

  # Helper to reassemble PLP chunks for roundtrip testing
  defp reassemble_plp(<<0::little-unsigned-32, _rest::binary>>),
    do: <<>>

  defp reassemble_plp(
         <<size::little-unsigned-32,
           chunk::binary-size(size), rest::binary>>
       ) do
    chunk <> reassemble_plp(rest)
  end
end
