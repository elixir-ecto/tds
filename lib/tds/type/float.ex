defmodule Tds.Type.Float do
  @moduledoc """
  TDS type handler for floating-point values.

  Handles fixed real (0x3B, 4-byte float-32), fixed float (0x3E,
  8-byte float-64) and variable floatn (0x6D) on decode.
  Always encodes as floatn (0x6D) with 8-byte float-64 to
  support NULL.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  @impl true
  def type_codes do
    [tds_type(:real), tds_type(:float), tds_type(:floatn)]
  end

  @impl true
  def type_names, do: [:float]

  # -- decode_metadata -----------------------------------------------

  @impl true
  def decode_metadata(<<tds_type(:real), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 4}}, rest}
  end

  def decode_metadata(<<tds_type(:float), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 8}}, rest}
  end

  def decode_metadata(
        <<tds_type(:floatn), length::unsigned-8, rest::binary>>
      ) do
    {:ok, %{data_reader: :bytelen, length: length}, rest}
  end

  # -- decode --------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil

  def decode(<<val::little-float-32>>, _metadata), do: val

  def decode(<<val::little-float-64>>, _metadata), do: val

  # -- encode --------------------------------------------------------

  @impl true
  def encode(nil, _metadata) do
    {tds_type(:floatn), <<0x08>>, <<0x00>>}
  end

  def encode(value, _metadata) when is_float(value) do
    {tds_type(:floatn), <<0x08>>, <<0x08, value::little-float-64>>}
  end

  # -- param_descriptor ----------------------------------------------

  @impl true
  def param_descriptor(nil, _metadata), do: "decimal(1,0)"
  def param_descriptor(_value, _metadata), do: "float(53)"

  # -- infer ---------------------------------------------------------

  @impl true
  def infer(value) when is_float(value), do: {:ok, %{}}
  def infer(_value), do: :skip
end
