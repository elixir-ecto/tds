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

  @spec encode(t) :: {:ok, <<_::40>>}
  def encode(%{codepage: :RAW}), do: {:ok, <<0x0::byte(5)>>}

  @spec decode(binary) :: {:ok, t} | {:error, :more} | {:error, any}
  def decode(<<0x0::byte(5)>>) do
    {:ok, %__MODULE__{codepage: :RAW}}
  end

  def decode(<<lcid::bit(20), col_flags::bit(8), version::bit(4), sort_id::byte()>>) do
    codepage = decode_sortid(sort_id) || decode_lcid(lcid) || "WINDOWS-1252"

    {:ok,
     %__MODULE__{
       codepage: codepage,
       lcid: lcid,
       sort_id: sort_id,
       version: version,
       col_flags: col_flags
     }}
  end

  def decode(_), do: raise(Tds.Error, "Unrecognized collation")

  @sort_ids %{
    "WINDOWS-437" => [0x1E, 0x1F, 0x20, 0x21, 0x22],
    "WINDOWS-850" => [
      0x28,
      0x29,
      0x2A,
      0x2B,
      0x2C,
      0x31,
      0x37,
      0x38,
      0x39,
      0x3A,
      0x3B,
      0x3C,
      0x3D
    ],
    "WINDOWS-1250" => [
      0x50,
      0x51,
      0x52,
      0x53,
      0x54,
      0x55,
      0x56,
      0x57,
      0x58,
      0x59,
      0x5A,
      0x5B,
      0x5C,
      0x5D,
      0x5E,
      0x5F,
      0x60
    ],
    "WINDOWS-1251" => [0x68, 0x69, 0x6A, 0x6B, 0x6C],
    "WINDOWS-1252" => [0x33, 0x34, 0x35, 0x36, 0xB7, 0xB8, 0xB9, 0xBA],
    "WINDOWS-1253" => [0x70, 0x71, 0x72, 0x78, 0x79, 0x7A, 0x7C],
    "WINDOWS-1254" => [0x80, 0x81, 0x82],
    "WINDOWS-1255" => [0x88, 0x89, 0x8A],
    "WINDOWS-1256" => [0x90, 0x91, 0x92],
    "WINDOWS-1257" => [0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 0xA0]
  }

  for {name, ids} <- @sort_ids do
    for id <- ids do
      defp decode_sortid(unquote(id)), do: unquote(name)
    end
  end

  defp decode_sortid(_id), do: nil

  @lcids %{
    "WINDOWS-874" => [0x0041E],
    "WINDOWS-932" => [0x00411, 0x10411],
    "WINDOWS-936" => [0x00804, 0x20804, 0x01004],
    "WINDOWS-949" => [0x00412],
    "WINDOWS-950" => [0x30404, 0x00404],
    "WINDOWS-1250" => [0x0041A, 0x00405, 0x0040E, 0x0104E, 0x00415, 0x00418, 0x0041B, 0x00424],
    "WINDOWS-1251" => [0x00423, 0x00402, 0x0041C, 0x00419, 0x0081A, 0x00C1A, 0x00422],
    "WINDOWS-1252" => [
      0x00436,
      0x0042D,
      0x00403,
      0x00406,
      0x00413,
      0x00813,
      0x00409,
      0x00809,
      0x01009,
      0x01409,
      0x00C09,
      0x01809,
      0x01C09,
      0x02409,
      0x02009,
      0x00438,
      0x0040B,
      0x0040C,
      0x0080C,
      0x0100C,
      0x00C0C,
      0x0140C,
      0x10437,
      0x10407,
      0x00407,
      0x00807,
      0x00C07,
      0x01007,
      0x01407,
      0x0040F,
      0x00421,
      0x00410,
      0x00810,
      0x00414,
      0x00814,
      0x00816,
      0x00416,
      0x0080A,
      0x0040A,
      0x00C0A,
      0x0100A,
      0x0140A,
      0x0180A,
      0x01C0A,
      0x0200A,
      0x0240A,
      0x0280A,
      0x02C0A,
      0x0300A,
      0x0340A,
      0x0380A,
      0x03C0A,
      0x0400A,
      0x0041D
    ],
    "WINDOWS-1253" => [0x00408],
    "WINDOWS-1254" => [0x0041F],
    "WINDOWS-1255" => [0x0040D],
    "WINDOWS-1256" => [
      0x00401,
      0x00801,
      0x00C01,
      0x01001,
      0x01401,
      0x01801,
      0x01C01,
      0x02001,
      0x02401,
      0x02801,
      0x02C01,
      0x03001,
      0x03401,
      0x03801,
      0x03C01,
      0x04001,
      0x00429,
      0x00420
    ],
    "WINDOWS-1257" => [0x00425, 0x00426, 0x00427, 0x00827],
    "WINDOWS-1258" => [0x0042A],
    "WINDOWS-UTF8" => [0x00439]
  }

  for {key, ids} <- @lcids do
    for id <- ids do
      defp decode_lcid(unquote(id)), do: unquote(key)
    end
  end

  defp decode_lcid(_id), do: nil
end
