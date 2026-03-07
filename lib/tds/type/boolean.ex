defmodule Tds.Type.Boolean do
  @moduledoc """
  TDS type handler for boolean values.

  Handles fixed bit (0x32) and variable bitn (0x68) on decode.
  Always encodes as bitn (0x68) to support NULL.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  @impl true
  def type_codes, do: [tds_type(:bit), tds_type(:bitn)]

  @impl true
  def type_names, do: [:boolean]

  @impl true
  def decode_metadata(<<tds_type(:bit), rest::binary>>) do
    {:ok, %{data_reader: {:fixed, 1}}, rest}
  end

  def decode_metadata(<<tds_type(:bitn), _length::unsigned-8, rest::binary>>) do
    {:ok, %{data_reader: :bytelen}, rest}
  end

  @impl true
  def decode(nil, _metadata), do: nil
  def decode(<<0x00>>, _metadata), do: false
  def decode(_data, _metadata), do: true

  @impl true
  def encode(nil, _metadata) do
    type = tds_type(:bitn)
    {type, <<type, 0x01>>, <<0x00>>}
  end

  def encode(value, _metadata) when is_boolean(value) do
    type = tds_type(:bitn)
    byte = if value, do: 0x01, else: 0x00
    {type, <<type, 0x01>>, <<0x01, byte>>}
  end

  @impl true
  def param_descriptor(_value, _metadata), do: "bit"

  @impl true
  def infer(value) when is_boolean(value), do: {:ok, %{}}
  def infer(_value), do: :skip
end
