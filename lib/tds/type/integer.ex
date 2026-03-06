defmodule Tds.Type.Integer do
  @moduledoc """
  TDS type handler for integer values.

  Handles fixed tinyint (0x30), smallint (0x34), int (0x38),
  bigint (0x7F) and variable intn (0x26) on decode.
  Always encodes as intn (0x26) to support NULL.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  @impl true
  def type_codes do
    [
      tds_type(:tinyint),
      tds_type(:smallint),
      tds_type(:int),
      tds_type(:bigint),
      tds_type(:intn)
    ]
  end

  @impl true
  def type_names, do: [:integer]

  # -- decode_metadata -----------------------------------------------

  @impl true
  def decode_metadata(<<tds_type(:tinyint), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 1}}, rest}
  end

  def decode_metadata(<<tds_type(:smallint), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 2}}, rest}
  end

  def decode_metadata(<<tds_type(:int), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 4}}, rest}
  end

  def decode_metadata(<<tds_type(:bigint), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 8}}, rest}
  end

  def decode_metadata(
        <<tds_type(:intn), length::unsigned-8, rest::binary>>
      ) do
    {:ok, %{data_reader: :bytelen, length: length}, rest}
  end

  # -- decode --------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil

  def decode(<<val::unsigned-8>>, _metadata), do: val

  def decode(<<val::little-signed-16>>, _metadata), do: val

  def decode(<<val::little-signed-32>>, _metadata), do: val

  def decode(<<val::little-signed-64>>, _metadata), do: val

  # -- encode --------------------------------------------------------

  @impl true
  def encode(nil, _metadata) do
    type = tds_type(:intn)
    {type, <<type, 0x04>>, <<0x00>>}
  end

  def encode(value, _metadata) when is_integer(value) do
    type = tds_type(:intn)
    size = wire_size(value)
    {type, <<type, size>>, [<<size>>, encode_value(value, size)]}
  end

  # -- param_descriptor ----------------------------------------------

  @impl true
  def param_descriptor(nil, _metadata), do: "int"

  def param_descriptor(0, _metadata), do: "int"

  def param_descriptor(value, _metadata) when value >= 1, do: "bigint"

  def param_descriptor(value, _metadata) when value < 0 do
    precision =
      value
      |> Integer.to_string()
      |> String.length()
      |> Kernel.-(1)

    "decimal(#{precision}, 0)"
  end

  # -- infer ---------------------------------------------------------

  @impl true
  def infer(value) when is_integer(value), do: {:ok, %{}}
  def infer(_value), do: :skip

  # -- private -------------------------------------------------------

  defp wire_size(value)
       when value in -2_147_483_648..2_147_483_647,
       do: 4

  defp wire_size(value)
       when value in -9_223_372_036_854_775_808..9_223_372_036_854_775_807,
       do: 8

  defp wire_size(value) do
    raise ArgumentError,
          "integer #{value} exceeds 64-bit range; " <>
            "use Decimal.new/1 instead"
  end

  defp encode_value(value, 4) do
    <<value::little-signed-32>>
  end

  defp encode_value(value, 8) do
    <<value::little-signed-64>>
  end
end
