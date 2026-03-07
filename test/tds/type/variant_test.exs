defmodule Tds.Type.VariantTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Variant

  describe "type_codes/0" do
    test "returns variant type code 0x62" do
      codes = Variant.type_codes()

      assert 0x62 in codes
      assert length(codes) == 1
    end
  end

  describe "type_names/0" do
    test "returns :variant" do
      assert Variant.type_names() == [:variant]
    end
  end

  # -- decode_metadata -------------------------------------------------

  describe "decode_metadata/1" do
    test "reads 4-byte LE max_length and returns variant reader" do
      tail = <<0xAA, 0xBB>>
      input = <<0x62, 8009::little-signed-32>> <> tail

      assert {:ok, meta, ^tail} = Variant.decode_metadata(input)
      assert meta.data_reader == :variant
      assert meta.length == 8009
    end

    test "handles zero max_length" do
      tail = <<0xCC>>
      input = <<0x62, 0::little-signed-32>> <> tail

      assert {:ok, meta, ^tail} = Variant.decode_metadata(input)
      assert meta.data_reader == :variant
      assert meta.length == 0
    end
  end

  # -- decode ----------------------------------------------------------

  describe "decode/2" do
    test "nil returns nil" do
      assert Variant.decode(nil, %{}) == nil
    end

    test "binary data returns raw binary passthrough" do
      data = <<0x01, 0x02, 0x03, 0x04, 0x05>>
      assert Variant.decode(data, %{}) == data
    end

    test "empty binary returns empty binary" do
      assert Variant.decode(<<>>, %{}) == <<>>
    end

    test "returns independent copy of data" do
      big = :crypto.strong_rand_bytes(100)
      <<chunk::binary-size(20), _rest::binary>> = big
      result = Variant.decode(chunk, %{})
      assert result == chunk
      assert byte_size(result) == 20
    end
  end

  # -- encode ----------------------------------------------------------

  describe "encode/2" do
    test "raises for any value (stub)" do
      assert_raise RuntimeError, ~r/sql_variant/i, fn ->
        Variant.encode("anything", %{})
      end
    end

    test "raises for nil (stub)" do
      assert_raise RuntimeError, ~r/sql_variant/i, fn ->
        Variant.encode(nil, %{})
      end
    end
  end

  # -- param_descriptor ------------------------------------------------

  describe "param_descriptor/2" do
    test "returns sql_variant for any value" do
      assert Variant.param_descriptor("any", %{}) == "sql_variant"
    end

    test "returns sql_variant for nil" do
      assert Variant.param_descriptor(nil, %{}) == "sql_variant"
    end
  end

  # -- infer -----------------------------------------------------------

  describe "infer/1" do
    test "always returns :skip for strings" do
      assert :skip = Variant.infer("hello")
    end

    test "always returns :skip for nil" do
      assert :skip = Variant.infer(nil)
    end

    test "always returns :skip for integers" do
      assert :skip = Variant.infer(42)
    end

    test "always returns :skip for binaries" do
      assert :skip = Variant.infer(<<0xFF>>)
    end
  end
end
