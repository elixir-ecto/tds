defmodule Tds.Protocol.PacketTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tds.Protocol.Packet

  describe "encode/2" do
    test "empty payload returns empty list" do
      assert [] = Packet.encode(0x01, <<>>)
    end

    test "1-byte payload produces single packet with EOM" do
      [packet] = Packet.encode(0x01, <<0xAB>>)
      bin = IO.iodata_to_binary(packet)
      assert byte_size(bin) == 9
      <<0x01, 0x01, 0x00, 0x09, 0x00, 0x00, 0x01, 0x00, 0xAB>> = bin
    end

    test "exactly 4088 bytes produces single packet" do
      payload = :binary.copy(<<0xAB>>, 4088)
      packets = Packet.encode(0x01, payload)
      assert length(packets) == 1

      bin = IO.iodata_to_binary(hd(packets))
      assert byte_size(bin) == 4096
      <<0x01, 0x01, _::binary>> = bin
    end

    test "4089 bytes produces two packets" do
      payload = :binary.copy(<<0xAB>>, 4089)
      packets = Packet.encode(0x01, payload)
      assert length(packets) == 2

      [p1, p2] = Enum.map(packets, &IO.iodata_to_binary/1)
      <<0x01, 0x00, _::binary>> = p1
      assert byte_size(p1) == 4096
      <<0x01, 0x01, _::binary>> = p2
      assert byte_size(p2) == 9
    end

    test "exact multiple of 4088 bytes" do
      payload = :binary.copy(<<0xAB>>, 4088 * 3)
      packets = Packet.encode(0x01, payload)
      assert length(packets) == 3

      bins = Enum.map(packets, &IO.iodata_to_binary/1)
      <<_, 0x00, _::binary>> = Enum.at(bins, 0)
      <<_, 0x00, _::binary>> = Enum.at(bins, 1)
      <<_, 0x01, _::binary>> = Enum.at(bins, 2)
    end

    test "packet IDs increment starting from 1" do
      payload = :binary.copy(<<0xAB>>, 4088 * 3)
      packets = Packet.encode(0x01, payload)

      ids =
        Enum.map(packets, fn p ->
          <<_::binary-6, id::8, _::binary>> = IO.iodata_to_binary(p)
          id
        end)

      assert ids == [1, 2, 3]
    end

    test "packet IDs wrap at 256" do
      payload = :binary.copy(<<0xAB>>, 4088 * 256 + 1)
      packets = Packet.encode(0x01, payload)
      assert length(packets) == 257

      ids =
        Enum.map(packets, fn p ->
          <<_::binary-6, id::8, _::binary>> = IO.iodata_to_binary(p)
          id
        end)

      assert Enum.at(ids, 0) == 1
      assert Enum.at(ids, 254) == 255
      assert Enum.at(ids, 255) == 0
      assert Enum.at(ids, 256) == 1
    end

    test "different packet types encode correctly" do
      types = [0x01, 0x03, 0x06, 0x0E, 0x10, 0x12]

      for type <- types do
        [packet] = Packet.encode(type, <<1, 2, 3>>)
        <<^type, _::binary>> = IO.iodata_to_binary(packet)
      end
    end

    test "SPID is always zero in encoded packets" do
      [packet] = Packet.encode(0x01, <<1, 2, 3>>)
      <<_::binary-4, spid::16, _::binary>> = IO.iodata_to_binary(packet)
      assert spid == 0
    end

    test "round-trip: stripping headers recovers payload" do
      payload = :binary.copy(<<0xAB>>, 4088 * 3 + 500)
      packets = Packet.encode(0x01, payload)

      reassembled =
        packets
        |> Enum.map(fn p ->
          <<_::binary-8, data::binary>> = IO.iodata_to_binary(p)
          data
        end)
        |> IO.iodata_to_binary()

      assert reassembled == payload
    end

    property "encode then strip headers recovers arbitrary payloads" do
      check all(
              size <- integer(0..50_000),
              type <- member_of([0x01, 0x03, 0x06, 0x0E, 0x10, 0x12]),
              byte_val <- integer(0..255)
            ) do
        payload = :binary.copy(<<byte_val>>, size)
        packets = Packet.encode(type, payload)

        reassembled =
          packets
          |> Enum.map(fn p ->
            <<_::binary-8, data::binary>> = IO.iodata_to_binary(p)
            data
          end)
          |> IO.iodata_to_binary()

        assert reassembled == payload
      end
    end
  end

  describe "decode_header/1" do
    test "parses valid 8-byte header" do
      data =
        <<0x04, 0x01, 0x00, 0x0D, 0x34, 0x00, 0x05, 0x00, "hello">>

      assert {:ok, header, "hello"} = Packet.decode_header(data)
      assert header.type == 0x04
      assert header.status == 0x01
      assert header.length == 13
      assert header.spid == 0x0034
      assert header.packet_id == 5
      assert header.window == 0
    end

    test "parses header with no remaining data" do
      data = <<0x04, 0x01, 0x00, 0x08, 0x00, 0x00, 0x01, 0x00>>
      assert {:ok, header, <<>>} = Packet.decode_header(data)
      assert header.type == 0x04
      assert header.length == 8
    end

    test "returns error for fewer than 8 bytes" do
      assert {:error, :incomplete_header} =
               Packet.decode_header(<<1, 2, 3>>)
    end

    test "returns error for empty binary" do
      assert {:error, :incomplete_header} = Packet.decode_header(<<>>)
    end

    test "returns error for exactly 7 bytes" do
      assert {:error, :incomplete_header} =
               Packet.decode_header(<<0, 0, 0, 0, 0, 0, 0>>)
    end
  end
end
