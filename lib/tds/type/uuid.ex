defmodule Tds.Type.UUID do
  @moduledoc """
  TDS type handler for UUID (uniqueidentifier) values.

  MSSQL stores UUIDs in mixed-endian format: groups 1 (4B), 2 (2B),
  3 (2B) are byte-reversed (little-endian), groups 4-5 (8B) are
  big-endian. This handler reorders bytes so that Elixir code works
  with standard RFC 4122 binary representation.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  # -- type_codes / type_names -----------------------------------------

  @impl true
  def type_codes, do: [tds_type(:uniqueidentifier)]

  @impl true
  def type_names, do: [:uuid]

  # -- decode_metadata -------------------------------------------------

  @impl true
  def decode_metadata(
        <<tds_type(:uniqueidentifier), _length::unsigned-8,
          rest::binary>>
      ) do
    {:ok, %{data_reader: :bytelen}, rest}
  end

  # -- decode ----------------------------------------------------------

  # NOTE: Byte reordering is disabled during the transition period.
  # The old encode path (Tds.Types) sends bytes without reordering,
  # so decode must also skip reordering to preserve roundtrip.
  # Enable reorder(data) when encode is switched to this handler.
  @impl true
  def decode(nil, _metadata), do: nil
  def decode(data, _metadata), do: :binary.copy(data)

  # -- encode ----------------------------------------------------------

  @impl true
  def encode(nil, _metadata) do
    type = tds_type(:uniqueidentifier)
    {type, <<type, 0x10>>, <<0x00>>}
  end

  def encode(<<_::128>> = bin, _metadata) do
    type = tds_type(:uniqueidentifier)
    wire = reorder(bin)
    {type, <<type, 0x10>>, <<0x10>> <> wire}
  end

  def encode(
        <<_::64, ?-, _::32, ?-, _::32, ?-, _::32, ?-, _::96>> = str,
        metadata
      ) do
    encode(parse_uuid_string(str), metadata)
  end

  # -- param_descriptor ------------------------------------------------

  @impl true
  def param_descriptor(_value, _metadata), do: "uniqueidentifier"

  # -- infer -----------------------------------------------------------

  @impl true
  def infer(<<_::128>>), do: {:ok, %{}}
  def infer(_value), do: :skip

  # -- private helpers -------------------------------------------------

  defp reorder(
         <<a::binary-4, b::binary-2, c::binary-2, rest::binary-8>>
       ) do
    reverse(a) <> reverse(b) <> reverse(c) <> rest
  end

  defp reverse(bin) do
    bin
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end

  defp parse_uuid_string(
         <<a1, a2, a3, a4, a5, a6, a7, a8, ?-,
           b1, b2, b3, b4, ?-,
           c1, c2, c3, c4, ?-,
           d1, d2, d3, d4, ?-,
           e1, e2, e3, e4, e5, e6, e7, e8,
           e9, e10, e11, e12>>
       ) do
    <<
      hex(a1)::4, hex(a2)::4, hex(a3)::4, hex(a4)::4,
      hex(a5)::4, hex(a6)::4, hex(a7)::4, hex(a8)::4,
      hex(b1)::4, hex(b2)::4, hex(b3)::4, hex(b4)::4,
      hex(c1)::4, hex(c2)::4, hex(c3)::4, hex(c4)::4,
      hex(d1)::4, hex(d2)::4, hex(d3)::4, hex(d4)::4,
      hex(e1)::4, hex(e2)::4, hex(e3)::4, hex(e4)::4,
      hex(e5)::4, hex(e6)::4, hex(e7)::4, hex(e8)::4,
      hex(e9)::4, hex(e10)::4, hex(e11)::4, hex(e12)::4
    >>
  end

  @compile {:inline, hex: 1}
  defp hex(?0), do: 0
  defp hex(?1), do: 1
  defp hex(?2), do: 2
  defp hex(?3), do: 3
  defp hex(?4), do: 4
  defp hex(?5), do: 5
  defp hex(?6), do: 6
  defp hex(?7), do: 7
  defp hex(?8), do: 8
  defp hex(?9), do: 9
  defp hex(?a), do: 10
  defp hex(?b), do: 11
  defp hex(?c), do: 12
  defp hex(?d), do: 13
  defp hex(?e), do: 14
  defp hex(?f), do: 15
  defp hex(?A), do: 10
  defp hex(?B), do: 11
  defp hex(?C), do: 12
  defp hex(?D), do: 13
  defp hex(?E), do: 14
  defp hex(?F), do: 15
end
