defmodule MessagesTest do
  use ExUnit.Case, async: true

  describe "encode_packets" do
    test "data length < 4088 is encoded into one packet" do
      assert [
               <<
                 # type
                 0x10,
                 # status
                 0x1,
                 # length
                 0x0,
                 0x9,
                 # channel
                 0x0,
                 0x0,
                 # packet number
                 0x1,
                 # window
                 0x0,
                 # data
                 0xFF
               >>
             ] == Tds.Messages.encode_packets(0x10, <<0xFF>>)
    end

    test "data length == 4087 is encoded into one packet" do
      data = :binary.copy(<<0xFF>>, 4087)

      assert [
               <<
                 # type
                 0x10,
                 # status
                 0x1,
                 # length
                 0x0F,
                 0xFF,
                 # channel
                 0x0,
                 0x0,
                 # packet number
                 0x1,
                 # window
                 0x0,
                 data::binary
               >>
             ] == Tds.Messages.encode_packets(0x10, data)
    end

    test "data length == 4088 is encoded into one packet" do
      data = :binary.copy(<<0xFF>>, 4088)

      assert [
               [
                 <<
                   # type
                   0x10,
                   # status
                   0x1,
                   # length
                   0x10,
                   0x00,
                   # channel
                   0x0,
                   0x0,
                   # packet number
                   0x1,
                   # window
                   0x0
                 >>,
                 <<
                   # data
                   data::binary
                 >>
               ]
             ] == Tds.Messages.encode_packets(0x10, data)
    end

    test "data length == 4089 is encoded into two packets " do
      part1 = :binary.copy(<<0xFF>>, 4088)
      part2 = :binary.copy(<<0xFF>>, 1)
      data = part1 <> part2

      assert [
               [
                 <<
                   # type
                   0x10,
                   # status
                   0x0,
                   # length
                   0x10,
                   0x00,
                   # channel
                   0x0,
                   0x0,
                   # packet number
                   0x1,
                   # window
                   0x0
                 >>,
                 <<
                   # data
                   part1::binary
                 >>
               ],
               <<
                 # type
                 0x10,
                 # status
                 0x1,
                 # length
                 0x0,
                 0x9,
                 # channel
                 0x0,
                 0x0,
                 # packet number
                 0x2,
                 # window
                 0x0,
                 # data
                 0xFF
               >>
             ] == Tds.Messages.encode_packets(0x10, data)
    end
  end
end
