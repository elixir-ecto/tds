defmodule Tds.Type.DataReaderTest do
  use ExUnit.Case, async: true

  alias Tds.Type.DataReader

  describe "read/2 :fixed" do
    test "reads fixed-length bytes" do
      assert {<<1, 2, 3, 4>>, <<0xFF>>} =
               DataReader.read({:fixed, 4}, <<1, 2, 3, 4, 0xFF>>)
    end

    test "reads 1-byte fixed" do
      assert {<<0x2A>>, <<>>} =
               DataReader.read({:fixed, 1}, <<0x2A>>)
    end
  end

  describe "read/2 :bytelen" do
    test "null marker 0x00 returns nil" do
      assert {nil, <<0xFF>>} =
               DataReader.read(:bytelen, <<0x00, 0xFF>>)
    end

    test "reads n bytes after length prefix" do
      assert {data, <<0xFF>>} =
               DataReader.read(:bytelen, <<0x03, 1, 2, 3, 0xFF>>)

      assert data == <<1, 2, 3>>
    end

    test "returned data is a copy (not sub-binary)" do
      payload = :crypto.strong_rand_bytes(200)
      input = <<200>> <> payload <> <<0xFF>>
      {data, _rest} = DataReader.read(:bytelen, input)
      assert :binary.referenced_byte_size(data) == byte_size(data)
    end
  end

  describe "read/2 :shortlen" do
    test "null marker 0xFFFF returns nil" do
      assert {nil, <<0xAA>>} =
               DataReader.read(:shortlen, <<0xFF, 0xFF, 0xAA>>)
    end

    test "reads n bytes after 2-byte LE length" do
      assert {data, <<0xBB>>} =
               DataReader.read(
                 :shortlen,
                 <<0x05, 0x00, 1, 2, 3, 4, 5, 0xBB>>
               )

      assert data == <<1, 2, 3, 4, 5>>
    end

    test "returned data is a copy" do
      payload = :crypto.strong_rand_bytes(200)
      input = <<200, 0x00>> <> payload <> <<0xFF>>
      {data, _rest} = DataReader.read(:shortlen, input)
      assert :binary.referenced_byte_size(data) == byte_size(data)
    end
  end

  describe "read/2 :longlen" do
    test "null marker 0x00 returns nil" do
      assert {nil, <<0xCC>>} =
               DataReader.read(:longlen, <<0x00, 0xCC>>)
    end

    test "reads past text_ptr and timestamp" do
      # text_ptr_size=2, text_ptr=0xAA 0xBB, timestamp=8 bytes,
      # data_size=3, data=1 2 3
      input =
        <<0x02, 0xAA, 0xBB>> <>
          <<0::unsigned-64>> <>
          <<0x03, 0x00, 0x00, 0x00>> <>
          <<1, 2, 3>> <>
          <<0xFF>>

      assert {<<1, 2, 3>>, <<0xFF>>} =
               DataReader.read(:longlen, input)
    end
  end

  describe "read/2 :plp" do
    test "null marker returns nil" do
      null_marker = <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>

      assert {nil, <<0xAA>>} =
               DataReader.read(:plp, null_marker <> <<0xAA>>)
    end

    test "single chunk" do
      input =
        <<10::little-unsigned-64>> <>
          <<5::little-unsigned-32, 1, 2, 3, 4, 5>> <>
          <<0::little-unsigned-32>> <>
          <<0xFF>>

      assert {<<1, 2, 3, 4, 5>>, <<0xFF>>} =
               DataReader.read(:plp, input)
    end

    test "multiple chunks reassembled in order" do
      input =
        <<6::little-unsigned-64>> <>
          <<3::little-unsigned-32, 1, 2, 3>> <>
          <<3::little-unsigned-32, 4, 5, 6>> <>
          <<0::little-unsigned-32>> <>
          <<0xBB>>

      assert {<<1, 2, 3, 4, 5, 6>>, <<0xBB>>} =
               DataReader.read(:plp, input)
    end

    test "empty PLP (zero-length total, immediate terminator)" do
      input =
        <<0::little-unsigned-64>> <>
          <<0::little-unsigned-32>> <>
          <<0xCC>>

      assert {<<>>, <<0xCC>>} =
               DataReader.read(:plp, input)
    end

    test "PLP result is independent binary (not sub-binary)" do
      chunk = :crypto.strong_rand_bytes(200)

      input =
        <<200::little-unsigned-64>> <>
          <<200::little-unsigned-32>> <>
          chunk <>
          <<0::little-unsigned-32>>

      {data, _rest} = DataReader.read(:plp, input)
      assert :binary.referenced_byte_size(data) == byte_size(data)
    end
  end

  describe "read/2 :variant" do
    test "zero length returns nil" do
      assert {nil, <<0xAA>>} =
               DataReader.read(:variant, <<0::little-unsigned-32, 0xAA>>)
    end

    test "reads n bytes after 4-byte LE length" do
      assert {data, <<0xBB>>} =
               DataReader.read(
                 :variant,
                 <<5::little-unsigned-32, 1, 2, 3, 4, 5, 0xBB>>
               )

      assert data == <<1, 2, 3, 4, 5>>
    end

    test "returned data is a copy (not sub-binary)" do
      payload = :crypto.strong_rand_bytes(200)
      input = <<200::little-unsigned-32>> <> payload <> <<0xFF>>
      {data, _rest} = DataReader.read(:variant, input)
      assert :binary.referenced_byte_size(data) == byte_size(data)
    end
  end
end
