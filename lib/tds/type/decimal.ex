defmodule Tds.Type.Decimal do
  @moduledoc """
  TDS type handler for decimal/numeric values.

  Handles legacy decimal (0x37), numeric (0x3F) and modern
  decimaln (0x6A), numericn (0x6C) on decode.
  Always encodes as decimaln (0x6A) to support NULL.

  Precision and scale come from metadata, never from
  the process dictionary.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  @impl true
  def type_codes do
    [
      tds_type(:decimal),
      tds_type(:numeric),
      tds_type(:decimaln),
      tds_type(:numericn)
    ]
  end

  @impl true
  def type_names, do: [:decimal, :numeric]

  # -- decode_metadata -----------------------------------------------

  @impl true
  def decode_metadata(<<tds_type(:decimaln), _len, p, s, rest::binary>>) do
    {:ok, %{data_reader: :bytelen, precision: p, scale: s}, rest}
  end

  def decode_metadata(<<tds_type(:numericn), _len, p, s, rest::binary>>) do
    {:ok, %{data_reader: :bytelen, precision: p, scale: s}, rest}
  end

  def decode_metadata(<<tds_type(:decimal), len, rest::binary>>) do
    {:ok, %{data_reader: :bytelen, length: len}, rest}
  end

  def decode_metadata(<<tds_type(:numeric), len, rest::binary>>) do
    {:ok, %{data_reader: :bytelen, length: len}, rest}
  end

  # -- decode --------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil

  def decode(<<sign::unsigned-8, value::binary>>, metadata) do
    size = byte_size(value)
    <<coef::little-unsigned-size(size)-unit(8)>> = value
    scale = Map.get(metadata, :scale, 0)

    case sign do
      1 -> Decimal.new(1, coef, -scale)
      0 -> Decimal.new(-1, coef, -scale)
    end
  end

  # -- encode --------------------------------------------------------

  @impl true
  def encode(nil, _metadata) do
    type = tds_type(:decimaln)
    {type, <<type, 0x01, 0x01, 0x00>>, <<0x00>>}
  end

  def encode(%Decimal{} = value, _metadata) do
    {precision, scale} = compute_precision_scale(value)
    type = tds_type(:decimaln)

    sign = if value.sign == 1, do: 1, else: 0
    coef_int = wire_coefficient(value, scale)

    coef_bytes = :binary.encode_unsigned(coef_int, :little)
    coef_size = byte_size(coef_bytes)
    data_len = data_length(precision)
    padding = data_len - coef_size
    value_size = data_len + 1
    padded = coef_bytes <> <<0::size(padding)-unit(8)>>

    meta = <<type, value_size, precision, scale>>
    val = <<value_size, sign>> <> padded
    {type, meta, val}
  end

  # -- param_descriptor ----------------------------------------------

  @impl true
  def param_descriptor(nil, _metadata), do: "decimal(1, 0)"

  def param_descriptor(%Decimal{} = value, _metadata) do
    {precision, scale} = compute_precision_scale(value)
    "decimal(#{precision}, #{scale})"
  end

  # -- infer ---------------------------------------------------------

  @impl true
  def infer(%Decimal{}), do: {:ok, %{}}
  def infer(_value), do: :skip

  # -- private -------------------------------------------------------

  defp compute_precision_scale(%Decimal{coef: coef, exp: exp}) do
    coef_digits = digit_count(coef)

    if exp >= 0 do
      {coef_digits + exp, 0}
    else
      scale = -exp
      int_digits = max(coef_digits + exp, 1)
      {int_digits + scale, scale}
    end
  end

  defp wire_coefficient(%Decimal{coef: coef, exp: exp}, scale) do
    # The wire integer is: abs(value) * 10^scale
    # which equals coef * 10^(exp + scale)
    shift = exp + scale
    coef * pow10(shift)
  end

  defp digit_count(0), do: 1

  defp digit_count(n) when is_integer(n) and n > 0 do
    n |> Integer.to_string() |> byte_size()
  end

  defp pow10(0), do: 1
  defp pow10(n) when n > 0, do: 10 ** n

  defp data_length(precision) when precision <= 9, do: 4
  defp data_length(precision) when precision <= 19, do: 8
  defp data_length(precision) when precision <= 28, do: 12
  defp data_length(precision) when precision <= 38, do: 16

  defp data_length(precision) do
    raise ArgumentError,
          "size (#{precision}) given to the type " <>
            "'decimal' exceeds the maximum allowed (38)"
  end
end
