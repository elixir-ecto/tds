defmodule Tds.Type.Xml do
  @moduledoc """
  TDS type handler for XML values.

  Handles 1 type code on decode:
  - xml (0xF1) — PLP with optional schema info

  Metadata includes a schema presence byte. If schema is present,
  db_name, owner_name, and collection_name are read and discarded
  (not needed for decode/encode).

  Always encodes as nvarchar for parameters (UCS-2 PLP).
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  alias Tds.Encoding.UCS2

  @null_collation <<0x00, 0x00, 0x00, 0x00, 0x00>>

  # -- type_codes / type_names ----------------------------------------

  @impl true
  def type_codes, do: [tds_type(:xml)]

  @impl true
  def type_names, do: [:xml]

  # -- decode_metadata ------------------------------------------------

  # No schema (0x00): just the presence byte
  @impl true
  def decode_metadata(<<tds_type(:xml), 0x00, rest::binary>>) do
    {:ok, %{data_reader: :plp}, rest}
  end

  # With schema (0x01): read and discard db, owner, collection
  def decode_metadata(<<tds_type(:xml), 0x01, rest::binary>>) do
    rest = skip_schema_info(rest)
    {:ok, %{data_reader: :plp}, rest}
  end

  # -- decode ---------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil
  def decode(<<>>, _metadata), do: ""
  def decode(data, _metadata), do: UCS2.to_string(data)

  # -- encode ---------------------------------------------------------

  @impl true
  def encode(nil, _metadata) do
    meta_bin = <<0xFF, 0xFF>> <> @null_collation
    value_bin = <<plp(:null)::little-unsigned-64>>
    {tds_type(:nvarchar), meta_bin, value_bin}
  end

  def encode(value, _metadata) when is_binary(value) do
    ucs2 = UCS2.from_string(value)
    ucs2_size = byte_size(ucs2)

    cond do
      ucs2_size == 0 ->
        meta_bin = <<0xFF, 0xFF>> <> @null_collation
        value_bin = <<0::unsigned-64, 0::unsigned-32>>
        {tds_type(:nvarchar), meta_bin, value_bin}

      ucs2_size > plp(:max_short_data_size) ->
        meta_bin = <<0xFF, 0xFF>> <> @null_collation
        value_bin = encode_plp(ucs2)
        {tds_type(:nvarchar), meta_bin, value_bin}

      true ->
        meta_bin =
          <<ucs2_size::little-unsigned-16>> <> @null_collation

        value_bin =
          <<ucs2_size::little-unsigned-16>> <> ucs2

        {tds_type(:nvarchar), meta_bin, value_bin}
    end
  end

  # -- param_descriptor ------------------------------------------------

  @impl true
  def param_descriptor(_value, _metadata), do: "xml"

  # -- infer -----------------------------------------------------------

  @impl true
  def infer(_value), do: :skip

  # -- private helpers -------------------------------------------------

  defp skip_schema_info(binary) do
    <<dblen::unsigned-8, _db::binary-size(dblen)-unit(16),
      ownerlen::unsigned-8, _owner::binary-size(ownerlen)-unit(16),
      schemalen::little-unsigned-16,
      _schema::binary-size(schemalen)-unit(16),
      rest::binary>> = binary

    rest
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
