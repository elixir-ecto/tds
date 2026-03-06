defmodule Tds.Type.Money do
  @moduledoc """
  TDS type handler for money values.

  Handles fixed money (0x3C, 8 bytes), fixed smallmoney (0x7A, 4 bytes),
  and variable moneyn (0x6E) on decode.

  Returns `%Decimal{}` instead of float for exact representation
  of monetary values. This is a breaking change from the old
  Tds.Types module which returned floats.

  Wire format:
  - smallmoney: 4-byte little-endian signed integer (1/10000 units)
  - money: 8 bytes, high 4 bytes then low 4 bytes (both LE),
    reinterpreted as a signed-64 value (1/10000 units)
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  @max_smallmoney_units 2_147_483_647
  @min_smallmoney_units -2_147_483_648

  @impl true
  def type_codes do
    [tds_type(:money), tds_type(:smallmoney), tds_type(:moneyn)]
  end

  @impl true
  def type_names, do: [:money, :smallmoney]

  @impl true
  def decode_metadata(<<tds_type(:money), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 8}}, rest}
  end

  def decode_metadata(<<tds_type(:smallmoney), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 4}}, rest}
  end

  def decode_metadata(
        <<tds_type(:moneyn), length::unsigned-8, rest::binary>>
      ) do
    {:ok, %{data_reader: :bytelen, length: length}, rest}
  end

  @impl true
  def decode(nil, _metadata), do: nil

  def decode(<<val::little-signed-32>>, _metadata) do
    sign = if val < 0, do: -1, else: 1
    Decimal.new(sign, abs(val), -4)
  end

  def decode(
        <<high::little-unsigned-32, low::little-unsigned-32>>,
        _metadata
      ) do
    <<combined::signed-64>> = <<high::32, low::32>>
    sign = if combined < 0, do: -1, else: 1
    Decimal.new(sign, abs(combined), -4)
  end

  @impl true
  def encode(nil, _metadata) do
    type = tds_type(:moneyn)
    {type, <<type, 0x08>>, <<0x00>>}
  end

  def encode(%Decimal{} = dec, _metadata) do
    type = tds_type(:moneyn)
    units = decimal_to_units(dec)
    <<high::unsigned-32, low::unsigned-32>> = <<units::signed-64>>

    {type, <<type, 0x08>>,
     <<0x08, high::little-unsigned-32, low::little-unsigned-32>>}
  end

  @impl true
  def param_descriptor(nil, _metadata), do: "money"

  def param_descriptor(%Decimal{} = dec, _metadata) do
    units = decimal_to_units(dec)

    if units >= @min_smallmoney_units and
         units <= @max_smallmoney_units do
      "smallmoney"
    else
      "money"
    end
  end

  @impl true
  def infer(_value), do: :skip

  defp decimal_to_units(%Decimal{sign: sign, coef: coef, exp: exp}) do
    scale_shift = exp + 4
    raw = if scale_shift >= 0, do: coef * pow10(scale_shift), else: div(coef, pow10(-scale_shift))
    if sign == -1, do: -raw, else: raw
  end

  defp pow10(0), do: 1
  defp pow10(n) when n > 0, do: 10 * pow10(n - 1)
end
