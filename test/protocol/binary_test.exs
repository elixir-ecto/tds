defmodule Tds.Protocol.BinaryTest do
  use ExUnit.Case, async: true

  import Tds.Protocol.Binary

  # ---------------------------------------------------------------------------
  # Little-endian macros (BinaryUtils baseline)
  # ---------------------------------------------------------------------------

  test "byte/0 works in pattern match" do
    <<val::byte()>> = <<0xFF>>
    assert val == 255
  end

  test "ushort/0 works in pattern match (little-endian unsigned 16-bit)" do
    <<val::ushort()>> = <<0x01, 0x00>>
    assert val == 1
  end

  test "ulong/0 works in pattern match (little-endian unsigned 32-bit)" do
    <<val::ulong()>> = <<0x01, 0x00, 0x00, 0x00>>
    assert val == 1
  end

  test "dword/0 is alias for ulong/0" do
    <<val::dword()>> = <<0x04, 0x00, 0x00, 0x00>>
    assert val == 4
  end

  test "long/0 works (little-endian signed 32-bit)" do
    <<val::long()>> = <<0xFF, 0xFF, 0xFF, 0xFF>>
    assert val == -1
  end

  test "longlong/0 works (little-endian signed 64-bit)" do
    <<val::longlong()>> = <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
    assert val == -1
  end

  test "ulonglong/0 works (little-endian unsigned 64-bit)" do
    <<val::ulonglong()>> = <<0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>
    assert val == 1
  end

  test "int16/0 works (little-endian signed 16-bit)" do
    <<val::int16()>> = <<0xFF, 0xFF>>
    assert val == -1
  end

  test "float64/0 works (little-endian 64-bit float)" do
    <<val::float64()>> = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F>>
    assert val == 1.0
  end

  test "float32/0 works (little-endian 32-bit float)" do
    <<val::float32()>> = <<0x00, 0x00, 0x80, 0x3F>>
    assert val == 1.0
  end

  test "sixbyte/0 works (unsigned 48-bit)" do
    <<val::sixbyte()>> = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x01>>
    assert val == 1
  end

  test "bytelen/0 works (unsigned 8-bit length)" do
    <<len::bytelen()>> = <<0x0A>>
    assert len == 10
  end

  test "ushortlen/0 works (little-endian unsigned 16-bit length)" do
    <<len::ushortlen()>> = <<0x0A, 0x00>>
    assert len == 10
  end

  test "longlen/0 works (little-endian signed 32-bit length)" do
    <<len::longlen()>> = <<0xFF, 0xFF, 0xFF, 0xFF>>
    assert len == -1
  end

  test "ulonglonglen/0 works (little-endian unsigned 64-bit length)" do
    <<len::ulonglonglen()>> = <<0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>
    assert len == 1
  end

  test "precision/0 and scale/0 work (unsigned 8-bit)" do
    <<p::precision(), s::scale()>> = <<18, 4>>
    assert p == 18
    assert s == 4
  end

  test "binary/1 works for sized binary" do
    <<data::binary(3)>> = <<1, 2, 3>>
    assert data == <<1, 2, 3>>
  end

  test "binary/2 works for sized binary with unit" do
    <<data::binary(2, 16)>> = <<0, 1, 0, 2>>
    assert data == <<0, 1, 0, 2>>
  end

  test "unicode/1 works for UCS-2 binary" do
    <<data::unicode(2)>> = <<0x41, 0x00, 0x42, 0x00>>
    assert data == <<0x41, 0x00, 0x42, 0x00>>
  end

  # ---------------------------------------------------------------------------
  # Big-endian macros (for prelogin headers)
  # ---------------------------------------------------------------------------

  test "ushort(:big) works (big-endian unsigned 16-bit)" do
    <<val::ushort(:big)>> = <<0x00, 0x01>>
    assert val == 1
  end

  test "ulong(:big) works (big-endian unsigned 32-bit)" do
    <<val::ulong(:big)>> = <<0x00, 0x00, 0x00, 0x01>>
    assert val == 1
  end

  test "dword(:big) works (big-endian unsigned 32-bit)" do
    <<val::dword(:big)>> = <<0x00, 0x00, 0x00, 0x04>>
    assert val == 4
  end

  test "long(:big) works (big-endian signed 32-bit)" do
    <<val::long(:big)>> = <<0xFF, 0xFF, 0xFF, 0xFF>>
    assert val == -1
  end

  test "longlong(:big) works (big-endian signed 64-bit)" do
    <<val::longlong(:big)>> = <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
    assert val == -1
  end

  test "ulonglong(:big) works (big-endian unsigned 64-bit)" do
    <<val::ulonglong(:big)>> = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01>>
    assert val == 1
  end

  test "explicit :little matches default (no argument)" do
    bytes = <<0x01, 0x00>>
    <<default::ushort()>> = bytes
    <<explicit::ushort(:little)>> = bytes
    assert default == explicit
    assert default == 1
  end

  test "big-endian and little-endian produce different results for same bytes" do
    bytes = <<0x01, 0x00>>
    <<le::ushort()>> = bytes
    <<be::ushort(:big)>> = bytes
    assert le == 1
    assert be == 256
  end

  # ---------------------------------------------------------------------------
  # Parameterized macros (from Grammar, for collation etc.)
  # ---------------------------------------------------------------------------

  test "bit/1 works for multi-bit fields" do
    # 20-bit + 8-bit + 4-bit = 32 bits = 4 bytes
    <<a::bit(20), b::bit(8), c::bit(4)>> = <<0xAB, 0xCD, 0xEF, 0x12>>
    assert is_integer(a)
    assert is_integer(b)
    assert is_integer(c)
    assert a + b + c >= 0
  end

  test "byte/1 works for multi-byte fields" do
    <<data::byte(5)>> = <<0, 0, 0, 0, 0>>
    assert data == 0
  end

  test "uchar/1 works for multi-byte unsigned chars" do
    <<val::uchar(2)>> = <<0x01, 0x02>>
    assert val == 0x0102
  end

  test "unicodechar/1 works for UCS-2 character sequences" do
    # 2 UCS-2 chars = 4 bytes
    <<data::unicodechar(2)>> = <<0x00, 0x41, 0x00, 0x42>>
    assert is_integer(data)
  end

  test "bigbinary/1 works for sized binary" do
    <<data::bigbinary(4)>> = <<1, 2, 3, 4>>
    assert data == <<1, 2, 3, 4>>
  end

  test "charbin_null/1 works for 2-byte null marker" do
    <<val::charbin_null(2)>> = <<0xFF, 0xFF>>
    assert val == 0xFFFF
  end

  test "charbin_null/1 works for 4-byte null marker" do
    <<val::charbin_null(4)>> = <<0xFF, 0xFF, 0xFF, 0xFF>>
    assert val == 0xFFFFFFFF
  end
end
