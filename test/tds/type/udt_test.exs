defmodule Tds.Type.UdtTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Udt

  describe "type_codes/0" do
    test "returns UDT type code 0xF0" do
      codes = Udt.type_codes()

      assert 0xF0 in codes
      assert length(codes) == 1
    end
  end

  describe "type_names/0" do
    test "returns :udt" do
      assert Udt.type_names() == [:udt]
    end
  end

  # -- decode_metadata -----------------------------------------------

  describe "decode_metadata/1 with shortlen" do
    test "reads 2-byte LE max_length, shortlen reader" do
      tail = <<0xAA, 0xBB>>
      input = <<0xF0, 200::little-unsigned-16>> <> tail

      assert {:ok, meta, ^tail} = Udt.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.length == 200
    end
  end

  describe "decode_metadata/1 with PLP" do
    test "PLP marker 0xFFFF sets data_reader to :plp" do
      input = <<0xF0, 0xFF, 0xFF, 0xCC>>

      assert {:ok, meta, <<0xCC>>} = Udt.decode_metadata(input)
      assert meta.data_reader == :plp
      assert meta.length == 0xFFFF
    end
  end

  # -- decode --------------------------------------------------------

  describe "decode/2" do
    test "nil returns nil" do
      assert Udt.decode(nil, %{}) == nil
    end

    test "raw binary passthrough" do
      data = <<0x00, 0x01, 0xFF, 0xFE, 0x80, 0x7F>>
      result = Udt.decode(data, %{})
      assert result == data
    end

    test "returns independent copy of the data" do
      big = :crypto.strong_rand_bytes(100)
      <<chunk::binary-size(10), _rest::binary>> = big
      result = Udt.decode(chunk, %{})
      assert result == chunk
      assert byte_size(result) == 10
    end

    test "empty binary returns empty binary" do
      assert Udt.decode(<<>>, %{}) == <<>>
    end

    test "preserves arbitrary bytes including invalid UTF-8" do
      data = <<0xC0, 0xC1, 0xF5, 0xFF>>
      assert Udt.decode(data, %{}) == data
    end
  end

  # -- encode --------------------------------------------------------

  describe "encode/2" do
    test "nil produces bigvarbinary PLP null" do
      {type_code, meta_bin, value_bin} = Udt.encode(nil, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 0xFF, 0xFF>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0xFFFFFFFFFFFFFFFF::little-unsigned-64>>
    end

    test "short binary uses shortlen format" do
      data = <<1, 2, 3, 4, 5>>
      {type_code, meta_bin, value_bin} = Udt.encode(data, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 5::little-unsigned-16>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<5::little-unsigned-16, 1, 2, 3, 4, 5>>
    end

    test "empty binary encodes as PLP empty" do
      {type_code, meta_bin, value_bin} = Udt.encode(<<>>, %{})

      assert type_code == 0xA5
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xA5, 0xFF, 0xFF>>

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0::unsigned-64, 0::unsigned-32>>
    end

    test "large binary (> 8000 bytes) uses PLP format" do
      data = :crypto.strong_rand_bytes(8001)
      {type_code, meta_bin, value_bin} = Udt.encode(data, %{})

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
  end

  # -- param_descriptor -----------------------------------------------

  describe "param_descriptor/2" do
    test "nil returns varbinary(max)" do
      assert Udt.param_descriptor(nil, %{}) == "varbinary(max)"
    end

    test "non-empty binary returns varbinary(max)" do
      data = <<1, 2, 3>>
      assert Udt.param_descriptor(data, %{}) == "varbinary(max)"
    end

    test "empty binary returns varbinary(max)" do
      assert Udt.param_descriptor(<<>>, %{}) == "varbinary(max)"
    end
  end

  # -- infer ----------------------------------------------------------

  describe "infer/1" do
    test "always returns :skip for binaries" do
      assert :skip = Udt.infer(<<0xDE, 0xAD>>)
    end

    test "always returns :skip for nil" do
      assert :skip = Udt.infer(nil)
    end

    test "always returns :skip for strings" do
      assert :skip = Udt.infer("hello")
    end

    test "always returns :skip for integers" do
      assert :skip = Udt.infer(42)
    end
  end

  # -- roundtrip ------------------------------------------------------

  describe "encode/decode roundtrip" do
    test "short binary roundtrips" do
      original = <<0xDE, 0xAD, 0xBE, 0xEF>>
      {_type, _meta, value_bin} = Udt.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      # shortlen: 2-byte length prefix + raw data
      <<size::little-unsigned-16, data::binary-size(size)>> = value

      assert Udt.decode(data, %{}) == original
    end

    test "large binary roundtrips through PLP" do
      original = :crypto.strong_rand_bytes(10_000)
      {_type, _meta, value_bin} = Udt.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      # PLP: skip 8-byte total size, then reassemble chunks
      <<_total::little-unsigned-64, chunked::binary>> = value
      data = reassemble_plp(chunked)

      assert Udt.decode(data, %{}) == original
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
