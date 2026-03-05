defmodule Tds.Type.UUIDTest do
  use ExUnit.Case, async: true

  alias Tds.Type.UUID

  # MSSQL stores UUIDs in mixed-endian format:
  # Groups 1 (4B), 2 (2B), 3 (2B) are byte-reversed (little-endian).
  # Groups 4-5 (8B) are as-is (big-endian).
  #
  # RFC 4122:   01020304-0506-0708-090a-0b0c0d0e0f10
  # Wire/MSSQL: 04030201-0605-0807-090a-0b0c0d0e0f10

  @rfc_binary <<1, 2, 3, 4, 5, 6, 7, 8,
    9, 10, 11, 12, 13, 14, 15, 16>>

  @wire_binary <<4, 3, 2, 1, 6, 5, 8, 7,
    9, 10, 11, 12, 13, 14, 15, 16>>

  @uuid_string "01020304-0506-0708-090a-0b0c0d0e0f10"

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

    test "wire bytes are reordered to RFC 4122 binary" do
      assert UUID.decode(@wire_binary, %{}) == @rfc_binary
    end

    test "reorders only groups 1-3, leaves groups 4-5 intact" do
      # All zeros except group 4-5 which has distinct bytes
      wire = <<0, 0, 0, 0, 0, 0, 0, 0, 0xAA, 0xBB, 0xCC, 0xDD,
        0xEE, 0xFF, 0x11, 0x22>>

      result = UUID.decode(wire, %{})
      # Groups 4-5 should be unchanged
      <<_::binary-8, rest::binary-8>> = result
      assert rest == <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22>>
    end

    test "returns independent copy of the data" do
      big = @wire_binary <> :crypto.strong_rand_bytes(100)
      <<chunk::binary-16, _::binary>> = big
      result = UUID.decode(chunk, %{})
      assert result == @rfc_binary
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

    test "binary UUID reorders to wire format" do
      {type_code, meta_bin, value_bin} = UUID.encode(@rfc_binary, %{})

      assert type_code == 0x24
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0x24, 0x10>>
      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x10>> <> @wire_binary
    end

    test "string UUID is parsed and reordered to wire format" do
      {type_code, meta_bin, value_bin} = UUID.encode(@uuid_string, %{})

      assert type_code == 0x24
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0x24, 0x10>>
      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x10>> <> @wire_binary
    end

    test "string UUID is case-insensitive" do
      upper = "01020304-0506-0708-090A-0B0C0D0E0F10"
      {_type, _meta, value_bin} = UUID.encode(upper, %{})

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0x10>> <> @wire_binary
    end
  end

  # -- param_descriptor ------------------------------------------------

  describe "param_descriptor/2" do
    test "returns uniqueidentifier for any value" do
      assert UUID.param_descriptor(@rfc_binary, %{}) ==
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
      assert {:ok, %{}} = UUID.infer(@rfc_binary)
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
    test "binary UUID roundtrips through encode then decode" do
      {_type, _meta, value_bin} = UUID.encode(@rfc_binary, %{})
      value = IO.iodata_to_binary(value_bin)

      # Strip the 1-byte length prefix to get wire bytes
      <<0x10, wire::binary-16>> = value
      assert UUID.decode(wire, %{}) == @rfc_binary
    end

    test "string UUID roundtrips through encode then decode" do
      {_type, _meta, value_bin} = UUID.encode(@uuid_string, %{})
      value = IO.iodata_to_binary(value_bin)

      <<0x10, wire::binary-16>> = value
      assert UUID.decode(wire, %{}) == @rfc_binary
    end

    test "decode then encode roundtrips back to wire format" do
      rfc = UUID.decode(@wire_binary, %{})
      {_type, _meta, value_bin} = UUID.encode(rfc, %{})
      value = IO.iodata_to_binary(value_bin)

      <<0x10, wire::binary-16>> = value
      assert wire == @wire_binary
    end

    test "random UUID roundtrips" do
      random_rfc = :crypto.strong_rand_bytes(16)
      {_type, _meta, value_bin} = UUID.encode(random_rfc, %{})
      value = IO.iodata_to_binary(value_bin)
      <<0x10, wire::binary-16>> = value

      assert UUID.decode(wire, %{}) == random_rfc
    end
  end
end
