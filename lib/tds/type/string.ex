defmodule Tds.Type.String do
  @moduledoc """
  TDS type handler for string values.

  Handles 8 type codes on decode:
  - bigchar (0xAF), bigvarchar (0xA7) — single-byte with collation
  - nvarchar (0xE7), nchar (0xEF) — UCS-2 (UTF-16LE)
  - legacy varchar (0x27), legacy char (0x2F) — single-byte short
  - text (0x23), ntext (0x63) — longlen with table name parts

  Always encodes as nvarchar for parameters (UCS-2).
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  alias Tds.Encoding.UCS2
  alias Tds.Protocol.Collation

  @null_collation <<0x00, 0x00, 0x00, 0x00, 0x00>>

  # UCS-2 type codes (decode as UTF-16LE)
  @ucs2_types [tds_type(:nvarchar), tds_type(:nchar), tds_type(:ntext)]

  @impl true
  def type_codes do
    [
      tds_type(:bigchar),
      tds_type(:bigvarchar),
      tds_type(:nvarchar),
      tds_type(:nchar),
      tds_type(:text),
      tds_type(:varchar),
      tds_type(:char),
      tds_type(:ntext)
    ]
  end

  @impl true
  def type_names, do: [:string]

  # -- decode_metadata -------------------------------------------------

  # Big types: bigvarchar (0xA7), bigchar (0xAF), nvarchar (0xE7),
  # nchar (0xEF) — 2-byte LE max_length + 5-byte collation
  @impl true
  def decode_metadata(
        <<type_code, length::little-unsigned-16, collation_bin::binary-5, rest::binary>>
      )
      when type_code in [
             tds_type(:bigvarchar),
             tds_type(:bigchar),
             tds_type(:nvarchar),
             tds_type(:nchar)
           ] do
    {:ok, collation} = Collation.decode(collation_bin)
    data_reader = if length == 0xFFFF, do: :plp, else: :shortlen
    encoding = encoding_for(type_code)

    meta = %{
      data_reader: data_reader,
      collation: collation,
      encoding: encoding,
      length: length
    }

    {:ok, meta, rest}
  end

  # Legacy short types: varchar (0x27), char (0x2F) — 1-byte length
  # + 5-byte collation
  def decode_metadata(<<type_code, length::unsigned-8, collation_bin::binary-5, rest::binary>>)
      when type_code in [tds_type(:varchar), tds_type(:char)] do
    {:ok, collation} = Collation.decode(collation_bin)

    meta = %{
      data_reader: :bytelen,
      collation: collation,
      encoding: :single_byte,
      length: length
    }

    {:ok, meta, rest}
  end

  # text (0x23) — 4-byte length + collation + numparts table names
  def decode_metadata(
        <<tds_type(:text), length::little-unsigned-32, collation_bin::binary-5,
          numparts::signed-8, rest::binary>>
      ) do
    {:ok, collation} = Collation.decode(collation_bin)
    rest = skip_table_parts(numparts, rest)

    meta = %{
      data_reader: :longlen,
      collation: collation,
      encoding: :single_byte,
      length: length
    }

    {:ok, meta, rest}
  end

  # ntext (0x63) — 4-byte length + collation + numparts table names
  def decode_metadata(
        <<tds_type(:ntext), length::little-unsigned-32, collation_bin::binary-5,
          numparts::signed-8, rest::binary>>
      ) do
    {:ok, collation} = Collation.decode(collation_bin)
    rest = skip_table_parts(numparts, rest)

    meta = %{
      data_reader: :longlen,
      collation: collation,
      encoding: :ucs2,
      length: length
    }

    {:ok, meta, rest}
  end

  # -- decode ----------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil

  def decode(<<>>, _metadata), do: ""

  def decode(data, %{encoding: :ucs2}) do
    UCS2.to_string(data)
  end

  def decode(data, %{encoding: :single_byte, collation: col}) do
    Tds.Utils.decode_chars(data, col.codepage)
  end

  # -- encode ----------------------------------------------------------

  @impl true
  def encode(nil, _metadata) do
    type = tds_type(:nvarchar)
    meta_bin = <<type, 0xFF, 0xFF>> <> @null_collation
    value_bin = <<plp(:null)::little-unsigned-64>>
    {type, meta_bin, value_bin}
  end

  def encode(value, _metadata) when is_binary(value) do
    type = tds_type(:nvarchar)
    ucs2 = UCS2.from_string(value)
    ucs2_size = byte_size(ucs2)

    cond do
      ucs2_size == 0 ->
        meta_bin = <<type, 0xFF, 0xFF>> <> @null_collation
        value_bin = <<0::unsigned-64, 0::unsigned-32>>
        {type, meta_bin, value_bin}

      ucs2_size > 8000 ->
        meta_bin = <<type, 0xFF, 0xFF>> <> @null_collation
        value_bin = encode_plp(ucs2)
        {type, meta_bin, value_bin}

      true ->
        meta_bin =
          <<type, ucs2_size::little-unsigned-16>> <>
            @null_collation

        value_bin =
          <<ucs2_size::little-unsigned-16>> <> ucs2

        {type, meta_bin, value_bin}
    end
  end

  # -- param_descriptor ------------------------------------------------

  @impl true
  def param_descriptor(nil, _metadata), do: "nvarchar(1)"

  def param_descriptor(value, _metadata) when is_binary(value) do
    len = String.length(value)

    cond do
      len <= 0 -> "nvarchar(1)"
      len <= 2_000 -> "nvarchar(2000)"
      true -> "nvarchar(max)"
    end
  end

  # -- infer -----------------------------------------------------------

  @impl true
  def infer(value) when is_binary(value), do: {:ok, %{}}
  def infer(_value), do: :skip

  # -- private helpers -------------------------------------------------

  defp encoding_for(type_code) when type_code in @ucs2_types,
    do: :ucs2

  defp encoding_for(_type_code), do: :single_byte

  defp skip_table_parts(0, rest), do: rest

  defp skip_table_parts(n, rest) when n > 0 do
    <<tsize::little-unsigned-16, _table_name::binary-size(tsize)-unit(16), next::binary>> = rest

    skip_table_parts(n - 1, next)
  end

  defp encode_plp(data) do
    size = byte_size(data)

    <<size::little-unsigned-64>> <>
      encode_plp_chunks(size, data, <<>>) <>
      <<0::little-unsigned-32>>
  end

  defp encode_plp_chunks(0, _data, buf), do: buf

  defp encode_plp_chunks(size, data, buf) do
    # Use lower 32 bits of size as chunk size (matches Tds.Types)
    <<_hi::unsigned-32, chunk_size::unsigned-32>> =
      <<size::unsigned-64>>

    <<chunk::binary-size(chunk_size), rest::binary>> = data
    plp = <<chunk_size::little-unsigned-32>> <> chunk
    encode_plp_chunks(size - chunk_size, rest, buf <> plp)
  end
end
