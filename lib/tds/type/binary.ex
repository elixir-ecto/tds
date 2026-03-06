defmodule Tds.Type.Binary do
  @moduledoc """
  TDS type handler for binary values.

  Handles 5 type codes on decode:
  - bigbinary (0xAD), bigvarbinary (0xA5) — 2-byte max_length
  - legacy binary (0x2D), legacy varbinary (0x25) — 1-byte length
  - image (0x22) — longlen with table name parts

  Always encodes as bigvarbinary (0xA5) for parameters.
  No character encoding — raw binary passthrough.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  # -- type_codes / type_names ----------------------------------------

  @impl true
  def type_codes do
    [
      tds_type(:bigbinary),
      tds_type(:bigvarbinary),
      tds_type(:image),
      tds_type(:binary),
      tds_type(:varbinary)
    ]
  end

  @impl true
  def type_names, do: [:binary, :image]

  # -- decode_metadata ------------------------------------------------

  # Big types: bigbinary (0xAD), bigvarbinary (0xA5)
  # 2-byte LE max_length, shortlen or plp (0xFFFF)
  @impl true
  def decode_metadata(<<type_code, length::little-unsigned-16, rest::binary>>)
      when type_code in [tds_type(:bigbinary), tds_type(:bigvarbinary)] do
    data_reader = if length == 0xFFFF, do: :plp, else: :shortlen

    meta = %{
      data_reader: data_reader,
      length: length
    }

    {:ok, meta, rest}
  end

  # Legacy short types: binary (0x2D), varbinary (0x25)
  # 1-byte length, bytelen reader
  def decode_metadata(<<type_code, length::unsigned-8, rest::binary>>)
      when type_code in [tds_type(:binary), tds_type(:varbinary)] do
    meta = %{
      data_reader: :bytelen,
      length: length
    }

    {:ok, meta, rest}
  end

  # image (0x22): 4-byte length + numparts table names
  def decode_metadata(
        <<tds_type(:image), length::little-unsigned-32,
          numparts::signed-8, rest::binary>>
      ) do
    rest = skip_table_parts(numparts, rest)

    meta = %{
      data_reader: :longlen,
      length: length
    }

    {:ok, meta, rest}
  end

  # -- decode ---------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil
  def decode(<<>>, _metadata), do: <<>>

  def decode(data, _metadata) do
    :binary.copy(data)
  end

  # -- encode ---------------------------------------------------------

  @impl true
  def encode(value, metadata) when is_integer(value) do
    encode(<<value>>, metadata)
  end

  def encode(nil, _metadata) do
    type = tds_type(:bigvarbinary)
    meta_bin = <<type, 0xFF, 0xFF>>
    value_bin = <<plp(:null)::little-unsigned-64>>
    {type, meta_bin, value_bin}
  end

  def encode(value, _metadata) when is_binary(value) do
    type = tds_type(:bigvarbinary)
    size = byte_size(value)

    cond do
      size == 0 ->
        meta_bin = <<type, 0xFF, 0xFF>>
        value_bin = <<0::unsigned-64, 0::unsigned-32>>
        {type, meta_bin, value_bin}

      size > 8000 ->
        meta_bin = <<type, 0xFF, 0xFF>>
        value_bin = encode_plp(value)
        {type, meta_bin, value_bin}

      true ->
        meta_bin = <<type, size::little-unsigned-16>>
        value_bin = <<size::little-unsigned-16>> <> value
        {type, meta_bin, value_bin}
    end
  end

  # -- param_descriptor -----------------------------------------------

  @impl true
  def param_descriptor(value, metadata) when is_integer(value) do
    param_descriptor(<<value>>, metadata)
  end

  def param_descriptor(nil, _metadata), do: "varbinary(1)"

  def param_descriptor(value, _metadata) when is_binary(value) do
    if byte_size(value) <= 0 do
      "varbinary(1)"
    else
      "varbinary(max)"
    end
  end

  # -- infer ----------------------------------------------------------

  @impl true
  def infer(value) when is_binary(value) do
    if String.valid?(value) do
      :skip
    else
      {:ok, %{}}
    end
  end

  def infer(_value), do: :skip

  # -- private helpers ------------------------------------------------

  defp skip_table_parts(0, rest), do: rest

  defp skip_table_parts(n, rest) when n > 0 do
    <<tsize::little-unsigned-16,
      _table_name::binary-size(tsize)-unit(16),
      next::binary>> = rest

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
    <<_hi::unsigned-32, chunk_size::unsigned-32>> =
      <<size::unsigned-64>>

    <<chunk::binary-size(chunk_size), rest::binary>> = data
    plp = <<chunk_size::little-unsigned-32>> <> chunk
    encode_plp_chunks(size - chunk_size, rest, buf <> plp)
  end
end
