defmodule Tds.Packet.Decoder.Collation do
  import Tds.Packet.Grammar

  @moduledoc """
  The collation rule is used to specify collation information for character data
  or metadata describing character data.

  This is typically specified as part of the LOGIN7 message or part of a column
  definition in server results containing character data.

  For more information about column definition, see
  COLMETADATA in MS-TDS.pdf.
  """

  defstruct codepage: :CP1252,
            lcid: nil,
            sort_id: nil,
            col_flags: nil,
            version: nil

  @type t :: %__MODULE__{codepage: atom}
  @typedoc """
  Value representing how much bytes is read from binary
  """
  @type bute_len :: non_neg_integer

  @spec serialize(t) :: {:ok, <<_::40>>}
  def serialize(%{codepage: :RAW}), do: {:ok, <<0x0::byte(5)>>}

  @spec parse(binary) ::
          {:ok, t, bute_len}
          | {:error, :more}
          | {:error, any}
  def parse(<<0x0::byte(5), _::binary>>) do
    {:ok, struct!(__MODULE__, codepage: :RAW), 5}
  end

  def parse(<<
        lcid::bit(20),
        _col_flags::bit(8),
        _version::bit(4),
        sort_id::byte(),
        _::binary
      >>) do
    codepage =
      decode_sortid(sort_id) ||
        decode_lcid(lcid) ||
        :CP1252

    {:ok, struct!(__MODULE__, codepage: codepage), 5}
  end

  def parse(_), do: {:error, :more}

  defp decode_sortid(sortid) do
    case sortid do
      0x1E -> :CP437
      0x1F -> :CP437
      0x20 -> :CP437
      0x21 -> :CP437
      0x22 -> :CP437
      0x28 -> :CP850
      0x29 -> :CP850
      0x2A -> :CP850
      0x2B -> :CP850
      0x2C -> :CP850
      0x31 -> :CP850
      0x33 -> :CP1252
      0x34 -> :CP1252
      0x35 -> :CP1252
      0x36 -> :CP1252
      0x37 -> :CP850
      0x38 -> :CP850
      0x39 -> :CP850
      0x3A -> :CP850
      0x3B -> :CP850
      0x3C -> :CP850
      0x3D -> :CP850
      0x50 -> :CP1250
      0x51 -> :CP1250
      0x52 -> :CP1250
      0x53 -> :CP1250
      0x54 -> :CP1250
      0x55 -> :CP1250
      0x56 -> :CP1250
      0x57 -> :CP1250
      0x58 -> :CP1250
      0x59 -> :CP1250
      0x5A -> :CP1250
      0x5B -> :CP1250
      0x5C -> :CP1250
      0x5D -> :CP1250
      0x5E -> :CP1250
      0x5F -> :CP1250
      0x60 -> :CP1250
      0x68 -> :CP1251
      0x69 -> :CP1251
      0x6A -> :CP1251
      0x6B -> :CP1251
      0x6C -> :CP1251
      0x70 -> :CP1253
      0x71 -> :CP1253
      0x72 -> :CP1253
      0x78 -> :CP1253
      0x79 -> :CP1253
      0x7A -> :CP1253
      0x7C -> :CP1253
      0x80 -> :CP1254
      0x81 -> :CP1254
      0x82 -> :CP1254
      0x88 -> :CP1255
      0x89 -> :CP1255
      0x8A -> :CP1255
      0x90 -> :CP1256
      0x91 -> :CP1256
      0x92 -> :CP1256
      0x98 -> :CP1257
      0x99 -> :CP1257
      0x9A -> :CP1257
      0x9B -> :CP1257
      0x9C -> :CP1257
      0x9D -> :CP1257
      0x9E -> :CP1257
      0x9F -> :CP1257
      0xA0 -> :CP1257
      0xB7 -> :CP1252
      0xB8 -> :CP1252
      0xB9 -> :CP1252
      0xBA -> :CP1252
      # Don't use sort_id it is not SQL collation
      _ -> nil
    end
  end

  def decode_lcid(lcid) do
    case lcid do
      0x00436 -> :CP1252
      0x00401 -> :CP1256
      0x00801 -> :CP1256
      0x00C01 -> :CP1256
      0x01001 -> :CP1256
      0x01401 -> :CP1256
      0x01801 -> :CP1256
      0x01C01 -> :CP1256
      0x02001 -> :CP1256
      0x02401 -> :CP1256
      0x02801 -> :CP1256
      0x02C01 -> :CP1256
      0x03001 -> :CP1256
      0x03401 -> :CP1256
      0x03801 -> :CP1256
      0x03C01 -> :CP1256
      0x04001 -> :CP1256
      0x0042D -> :CP1252
      0x00423 -> :CP1251
      0x00402 -> :CP1251
      0x00403 -> :CP1252
      0x30404 -> :CP950
      0x00404 -> :CP950
      0x00804 -> :CP936
      0x20804 -> :CP936
      0x01004 -> :CP936
      0x0041A -> :CP1250
      0x00405 -> :CP1250
      0x00406 -> :CP1252
      0x00413 -> :CP1252
      0x00813 -> :CP1252
      0x00409 -> :CP1252
      0x00809 -> :CP1252
      0x01009 -> :CP1252
      0x01409 -> :CP1252
      0x00C09 -> :CP1252
      0x01809 -> :CP1252
      0x01C09 -> :CP1252
      0x02409 -> :CP1252
      0x02009 -> :CP1252
      0x00425 -> :CP1257
      0x00438 -> :CP1252
      0x00429 -> :CP1256
      0x0040B -> :CP1252
      0x0040C -> :CP1252
      0x0080C -> :CP1252
      0x0100C -> :CP1252
      0x00C0C -> :CP1252
      0x0140C -> :CP1252
      0x10437 -> :CP1252
      0x10407 -> :CP1252
      0x00407 -> :CP1252
      0x00807 -> :CP1252
      0x00C07 -> :CP1252
      0x01007 -> :CP1252
      0x01407 -> :CP1252
      0x00408 -> :CP1253
      0x0040D -> :CP1255
      0x00439 -> :CPUTF8
      0x0040E -> :CP1250
      0x0104E -> :CP1250
      0x0040F -> :CP1252
      0x00421 -> :CP1252
      0x00410 -> :CP1252
      0x00810 -> :CP1252
      0x00411 -> :CP932
      0x10411 -> :CP932
      0x00412 -> :CP949
      0x00426 -> :CP1257
      0x00427 -> :CP1257
      0x00827 -> :CP1257
      0x0041C -> :CP1251
      0x00414 -> :CP1252
      0x00814 -> :CP1252
      0x00415 -> :CP1250
      0x00816 -> :CP1252
      0x00416 -> :CP1252
      0x00418 -> :CP1250
      0x00419 -> :CP1251
      0x0081A -> :CP1251
      0x00C1A -> :CP1251
      0x0041B -> :CP1250
      0x00424 -> :CP1250
      0x0080A -> :CP1252
      0x0040A -> :CP1252
      0x00C0A -> :CP1252
      0x0100A -> :CP1252
      0x0140A -> :CP1252
      0x0180A -> :CP1252
      0x01C0A -> :CP1252
      0x0200A -> :CP1252
      0x0240A -> :CP1252
      0x0280A -> :CP1252
      0x02C0A -> :CP1252
      0x0300A -> :CP1252
      0x0340A -> :CP1252
      0x0380A -> :CP1252
      0x03C0A -> :CP1252
      0x0400A -> :CP1252
      0x0041D -> :CP1252
      0x0041E -> :CP874
      0x0041F -> :CP1254
      0x00422 -> :CP1251
      0x00420 -> :CP1256
      0x0042A -> :CP1258
      _ -> nil
    end
  end
end
