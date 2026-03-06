defmodule Tds.Type.Udt do
  @moduledoc """
  TDS type handler for CLR User-Defined Type values.

  Handles 1 type code on decode:
  - udt (0xF0) -- 2-byte LE max_length, shortlen or PLP

  UDT values are passed through as raw binary. Application code
  (e.g. Ecto custom types) is responsible for interpreting the
  binary payload. Built-in UDT types like HierarchyId are also
  returned as raw bytes.

  Always encodes as bigvarbinary (0xA5) for parameters.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  # -- type_codes / type_names ----------------------------------------

  @impl true
  def type_codes, do: [tds_type(:udt)]

  @impl true
  def type_names, do: [:udt]

  # -- decode_metadata ------------------------------------------------

  @impl true
  def decode_metadata(
        <<tds_type(:udt), length::little-unsigned-16,
          rest::binary>>
      ) do
    data_reader = if length == 0xFFFF, do: :plp, else: :shortlen

    meta = %{
      data_reader: data_reader,
      length: length
    }

    {:ok, meta, rest}
  end

  # -- decode ---------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil
  def decode(<<>>, _metadata), do: <<>>
  def decode(data, _metadata), do: :binary.copy(data)

  # -- encode ---------------------------------------------------------

  @impl true
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

  # -- param_descriptor ------------------------------------------------

  @impl true
  def param_descriptor(_value, _metadata), do: "varbinary(max)"

  # -- infer -----------------------------------------------------------

  @impl true
  def infer(_value), do: :skip

  # -- private helpers -------------------------------------------------

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
