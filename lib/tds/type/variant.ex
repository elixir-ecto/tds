defmodule Tds.Type.Variant do
  @moduledoc """
  TDS type handler for sql_variant values (stub).

  Handles 1 type code on decode:
  - variant (0x62) -- 4-byte LE max_length, variant data reader

  This is a stub handler. Decode returns raw binary without
  inner-type dispatch. Full variant decoding (reading the inner
  type code and delegating to the appropriate handler) is deferred.

  Encoding sql_variant parameters is not supported by TDS RPC,
  so encode raises at runtime.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  # -- type_codes / type_names ----------------------------------------

  @impl true
  def type_codes, do: [tds_type(:variant)]

  @impl true
  def type_names, do: [:variant]

  # -- decode_metadata ------------------------------------------------

  @impl true
  def decode_metadata(
        <<tds_type(:variant), length::little-signed-32,
          rest::binary>>
      ) do
    meta = %{
      data_reader: :variant,
      length: length
    }

    {:ok, meta, rest}
  end

  # -- decode ----------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil
  def decode(<<>>, _metadata), do: <<>>
  def decode(data, _metadata), do: :binary.copy(data)

  # -- encode ----------------------------------------------------------

  @impl true
  def encode(_value, _metadata) do
    raise RuntimeError,
          "sql_variant encoding is not supported. " <>
            "TDS does not allow sql_variant as an RPC parameter type."
  end

  # -- param_descriptor ------------------------------------------------

  @impl true
  def param_descriptor(_value, _metadata), do: "sql_variant"

  # -- infer -----------------------------------------------------------

  @impl true
  def infer(_value), do: :skip
end
