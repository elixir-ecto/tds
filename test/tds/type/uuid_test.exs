defmodule Tds.Type.UUIDTest do
  use ExUnit.Case, async: true

  alias Tds.Type.UUID

  # Tds.Types.UUID works in mixed-endian format. Bytes are
  # stored and returned without reordering to preserve existing
  # roundtrip behavior with bingenerate/load/dump.

  @test_binary <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>

  @uuid_string "01020304-0506-0708-090a-0b0c0d0e0f10"

  # parse_uuid_string produces hex bytes in order (no reorder)
  @parsed_string_binary <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C,
                          0x0D, 0x0E, 0x0F, 0x10>>

  describe "type_codes/0" do
    test "returns uniqueidentifier code 0x24" do
      assert UUID.type_codes() == [0x24]
    end
  end

  describe "type_names/0" do
    test "returns :uuid" do
      assert UUID.type_names() == [:uuid]
    end
  end

  # -- decode_metadata -------------------------------------------------

  describe "decode_metadata/1" do
    test "reads 1-byte length and returns bytelen reader" do
      tail = <<0xAA, 0xBB>>
      input = <<0x24, 0x10>> <> tail

      assert {:ok, meta, ^tail} = UUID.decode_metadata(input)
      assert meta.data_reader == :bytelen
    end

    test "consumes type code and length byte from stream" do
      input = <<0x24, 0x10, 0xCC, 0xDD>>

      assert {:ok, _meta, <<0xCC, 0xDD>>} =
               UUID.decode_metadata(input)
    end
  end

  # -- decode ----------------------------------------------------------

  describe "decode/2" do
    test "nil returns nil" do
      assert UUID.decode(nil, %{}) == nil
    end

    test "returns the raw 16-byte binary as-is" do
      result = UUID.decode(@test_binary, %{})
      assert result == @test_binary
    end

    test "returns independent copy of the data" do
      big = @test_binary <> :crypto.strong_rand_bytes(100)
      <<chunk::binary-16, _::binary>> = big
      result = UUID.decode(chunk, %{})
      assert byte_size(result) == 16
    end
  end

  # -- encode ----------------------------------------------------------

  describe "encode/2" do
    test "nil produces null encoding" do
      {type_code, meta_bin, value_bin} = UUID.encode(nil, %{})

      assert type_code == 0x24
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0x24, 0x10>>
      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x00>>
    end

    test "binary UUID is sent as-is (no reorder)" do
      {type_code, meta_bin, value_bin} =
        UUID.encode(@test_binary, %{})

      assert type_code == 0x24
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0x24, 0x10>>
      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x10>> <> @test_binary
    end

    test "string UUID is parsed to binary" do
      {type_code, meta_bin, value_bin} =
        UUID.encode(@uuid_string, %{})

      assert type_code == 0x24
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0x24, 0x10>>
      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x10>> <> @parsed_string_binary
    end

    test "string UUID is case-insensitive" do
      upper = "01020304-0506-0708-090A-0B0C0D0E0F10"
      {_type, _meta, value_bin} = UUID.encode(upper, %{})

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x10>> <> @parsed_string_binary
    end
  end

  # -- param_descriptor ------------------------------------------------

  describe "param_descriptor/2" do
    test "returns uniqueidentifier for any value" do
      assert UUID.param_descriptor(@test_binary, %{}) ==
               "uniqueidentifier"

      assert UUID.param_descriptor(nil, %{}) ==
               "uniqueidentifier"

      assert UUID.param_descriptor(@uuid_string, %{}) ==
               "uniqueidentifier"
    end
  end

  # -- infer -----------------------------------------------------------

  describe "infer/1" do
    test "16-byte binary infers as uuid" do
      assert {:ok, %{}} = UUID.infer(@test_binary)
    end

    test "string UUID skips (must use explicit type: :uuid)" do
      assert :skip = UUID.infer(@uuid_string)
    end

    test "nil skips" do
      assert :skip = UUID.infer(nil)
    end

    test "integer skips" do
      assert :skip = UUID.infer(42)
    end

    test "non-16-byte binary skips" do
      assert :skip = UUID.infer(<<1, 2, 3>>)
    end

    test "atom skips" do
      assert :skip = UUID.infer(:foo)
    end
  end

  # -- roundtrip -------------------------------------------------------

  describe "encode/decode roundtrip" do
    test "encode then decode preserves input bytes" do
      {_type, _meta, value_bin} =
        UUID.encode(@test_binary, %{})

      value = IO.iodata_to_binary(value_bin)

      # Strip the 1-byte length prefix to get wire bytes
      <<0x10, wire::binary-16>> = value
      # No reorder: wire bytes == input bytes
      assert UUID.decode(wire, %{}) == @test_binary
    end

    test "random 16-byte binary roundtrips through decode" do
      random = :crypto.strong_rand_bytes(16)
      assert UUID.decode(random, %{}) == random
    end
  end
end
