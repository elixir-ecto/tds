defmodule Tds.Protocol.Collation do
  @moduledoc """
  The collation rule is used to specify collation information for character data
  or metadata describing character data.

  This is typically specified as part of the LOGIN7 message or part of a column
  definition in server results containing character data.

  For more information about column definition, see
  COLMETADATA in MS-TDS.pdf.
  """

  import Tds.Protocol.Grammar

  defstruct codepage: "WINDOWS-1252",
            lcid: nil,
            sort_id: nil,
            col_flags: nil,
            version: nil

  @type t :: %__MODULE__{
          codepage: String.t() | :RAW,
          lcid: nil | non_neg_integer,
          sort_id: non_neg_integer,
          col_flags: non_neg_integer,
          version: non_neg_integer
        }
  @typedoc """
  Value representing how much bytes is read from binary
  """
  @type bute_len :: non_neg_integer

  @spec encode(t) :: {:ok, <<_::40>>}
  def encode(%{codepage: :RAW}), do: {:ok, <<0x0::byte(5)>>}

  @spec decode(binary) ::
          {:ok, t}
          | {:error, :more}
          | {:error, any}
  def decode(<<0x0::byte(5)>>) do
    {:ok, struct!(__MODULE__, codepage: :RAW)}
  end

  def decode(<<
        lcid::bit(20),
        col_flags::bit(8),
        version::bit(4),
        sort_id::byte()
      >>) do
    codepage =
      decode_sortid(sort_id) ||
        decode_lcid(lcid) ||
        "WINDOWS-1252"

    {:ok,
     struct!(__MODULE__,
       codepage: codepage,
       lcid: lcid,
       sort_id: sort_id,
       version: version,
       col_flags: col_flags
     )}
  end

  def decode(_), do: raise(Tds.Error, "Unrecognized collation")

  defp decode_sortid(sortid) do
    case sortid do
      0x1E -> "WINDOWS-437"
      0x1F -> "WINDOWS-437"
      0x20 -> "WINDOWS-437"
      0x21 -> "WINDOWS-437"
      0x22 -> "WINDOWS-437"
      0x28 -> "WINDOWS-850"
      0x29 -> "WINDOWS-850"
      0x2A -> "WINDOWS-850"
      0x2B -> "WINDOWS-850"
      0x2C -> "WINDOWS-850"
      0x31 -> "WINDOWS-850"
      0x33 -> "WINDOWS-1252"
      0x34 -> "WINDOWS-1252"
      0x35 -> "WINDOWS-1252"
      0x36 -> "WINDOWS-1252"
      0x37 -> "WINDOWS-850"
      0x38 -> "WINDOWS-850"
      0x39 -> "WINDOWS-850"
      0x3A -> "WINDOWS-850"
      0x3B -> "WINDOWS-850"
      0x3C -> "WINDOWS-850"
      0x3D -> "WINDOWS-850"
      0x50 -> "WINDOWS-1250"
      0x51 -> "WINDOWS-1250"
      0x52 -> "WINDOWS-1250"
      0x53 -> "WINDOWS-1250"
      0x54 -> "WINDOWS-1250"
      0x55 -> "WINDOWS-1250"
      0x56 -> "WINDOWS-1250"
      0x57 -> "WINDOWS-1250"
      0x58 -> "WINDOWS-1250"
      0x59 -> "WINDOWS-1250"
      0x5A -> "WINDOWS-1250"
      0x5B -> "WINDOWS-1250"
      0x5C -> "WINDOWS-1250"
      0x5D -> "WINDOWS-1250"
      0x5E -> "WINDOWS-1250"
      0x5F -> "WINDOWS-1250"
      0x60 -> "WINDOWS-1250"
      0x68 -> "WINDOWS-1251"
      0x69 -> "WINDOWS-1251"
      0x6A -> "WINDOWS-1251"
      0x6B -> "WINDOWS-1251"
      0x6C -> "WINDOWS-1251"
      0x70 -> "WINDOWS-1253"
      0x71 -> "WINDOWS-1253"
      0x72 -> "WINDOWS-1253"
      0x78 -> "WINDOWS-1253"
      0x79 -> "WINDOWS-1253"
      0x7A -> "WINDOWS-1253"
      0x7C -> "WINDOWS-1253"
      0x80 -> "WINDOWS-1254"
      0x81 -> "WINDOWS-1254"
      0x82 -> "WINDOWS-1254"
      0x88 -> "WINDOWS-1255"
      0x89 -> "WINDOWS-1255"
      0x8A -> "WINDOWS-1255"
      0x90 -> "WINDOWS-1256"
      0x91 -> "WINDOWS-1256"
      0x92 -> "WINDOWS-1256"
      0x98 -> "WINDOWS-1257"
      0x99 -> "WINDOWS-1257"
      0x9A -> "WINDOWS-1257"
      0x9B -> "WINDOWS-1257"
      0x9C -> "WINDOWS-1257"
      0x9D -> "WINDOWS-1257"
      0x9E -> "WINDOWS-1257"
      0x9F -> "WINDOWS-1257"
      0xA0 -> "WINDOWS-1257"
      0xB7 -> "WINDOWS-1252"
      0xB8 -> "WINDOWS-1252"
      0xB9 -> "WINDOWS-1252"
      0xBA -> "WINDOWS-1252"
      # Don't use sort_id it is not SQL collation
      _ -> nil
    end
  end

  def decode_lcid(lcid) do
    case lcid do
      0x00436 -> "WINDOWS-1252"
      0x00401 -> "WINDOWS-1256"
      0x00801 -> "WINDOWS-1256"
      0x00C01 -> "WINDOWS-1256"
      0x01001 -> "WINDOWS-1256"
      0x01401 -> "WINDOWS-1256"
      0x01801 -> "WINDOWS-1256"
      0x01C01 -> "WINDOWS-1256"
      0x02001 -> "WINDOWS-1256"
      0x02401 -> "WINDOWS-1256"
      0x02801 -> "WINDOWS-1256"
      0x02C01 -> "WINDOWS-1256"
      0x03001 -> "WINDOWS-1256"
      0x03401 -> "WINDOWS-1256"
      0x03801 -> "WINDOWS-1256"
      0x03C01 -> "WINDOWS-1256"
      0x04001 -> "WINDOWS-1256"
      0x0042D -> "WINDOWS-1252"
      0x00423 -> "WINDOWS-1251"
      0x00402 -> "WINDOWS-1251"
      0x00403 -> "WINDOWS-1252"
      0x30404 -> "WINDOWS-950"
      0x00404 -> "WINDOWS-950"
      0x00804 -> "WINDOWS-936"
      0x20804 -> "WINDOWS-936"
      0x01004 -> "WINDOWS-936"
      0x0041A -> "WINDOWS-1250"
      0x00405 -> "WINDOWS-1250"
      0x00406 -> "WINDOWS-1252"
      0x00413 -> "WINDOWS-1252"
      0x00813 -> "WINDOWS-1252"
      0x00409 -> "WINDOWS-1252"
      0x00809 -> "WINDOWS-1252"
      0x01009 -> "WINDOWS-1252"
      0x01409 -> "WINDOWS-1252"
      0x00C09 -> "WINDOWS-1252"
      0x01809 -> "WINDOWS-1252"
      0x01C09 -> "WINDOWS-1252"
      0x02409 -> "WINDOWS-1252"
      0x02009 -> "WINDOWS-1252"
      0x00425 -> "WINDOWS-1257"
      0x00438 -> "WINDOWS-1252"
      0x00429 -> "WINDOWS-1256"
      0x0040B -> "WINDOWS-1252"
      0x0040C -> "WINDOWS-1252"
      0x0080C -> "WINDOWS-1252"
      0x0100C -> "WINDOWS-1252"
      0x00C0C -> "WINDOWS-1252"
      0x0140C -> "WINDOWS-1252"
      0x10437 -> "WINDOWS-1252"
      0x10407 -> "WINDOWS-1252"
      0x00407 -> "WINDOWS-1252"
      0x00807 -> "WINDOWS-1252"
      0x00C07 -> "WINDOWS-1252"
      0x01007 -> "WINDOWS-1252"
      0x01407 -> "WINDOWS-1252"
      0x00408 -> "WINDOWS-1253"
      0x0040D -> "WINDOWS-1255"
      0x00439 -> "WINDOWS-UTF8"
      0x0040E -> "WINDOWS-1250"
      0x0104E -> "WINDOWS-1250"
      0x0040F -> "WINDOWS-1252"
      0x00421 -> "WINDOWS-1252"
      0x00410 -> "WINDOWS-1252"
      0x00810 -> "WINDOWS-1252"
      0x00411 -> "WINDOWS-932"
      0x10411 -> "WINDOWS-932"
      0x00412 -> "WINDOWS-949"
      0x00426 -> "WINDOWS-1257"
      0x00427 -> "WINDOWS-1257"
      0x00827 -> "WINDOWS-1257"
      0x0041C -> "WINDOWS-1251"
      0x00414 -> "WINDOWS-1252"
      0x00814 -> "WINDOWS-1252"
      0x00415 -> "WINDOWS-1250"
      0x00816 -> "WINDOWS-1252"
      0x00416 -> "WINDOWS-1252"
      0x00418 -> "WINDOWS-1250"
      0x00419 -> "WINDOWS-1251"
      0x0081A -> "WINDOWS-1251"
      0x00C1A -> "WINDOWS-1251"
      0x0041B -> "WINDOWS-1250"
      0x00424 -> "WINDOWS-1250"
      0x0080A -> "WINDOWS-1252"
      0x0040A -> "WINDOWS-1252"
      0x00C0A -> "WINDOWS-1252"
      0x0100A -> "WINDOWS-1252"
      0x0140A -> "WINDOWS-1252"
      0x0180A -> "WINDOWS-1252"
      0x01C0A -> "WINDOWS-1252"
      0x0200A -> "WINDOWS-1252"
      0x0240A -> "WINDOWS-1252"
      0x0280A -> "WINDOWS-1252"
      0x02C0A -> "WINDOWS-1252"
      0x0300A -> "WINDOWS-1252"
      0x0340A -> "WINDOWS-1252"
      0x0380A -> "WINDOWS-1252"
      0x03C0A -> "WINDOWS-1252"
      0x0400A -> "WINDOWS-1252"
      0x0041D -> "WINDOWS-1252"
      0x0041E -> "WINDOWS-874"
      0x0041F -> "WINDOWS-1254"
      0x00422 -> "WINDOWS-1251"
      0x00420 -> "WINDOWS-1256"
      0x0042A -> "WINDOWS-1258"
      _ -> nil
    end
  end
end
