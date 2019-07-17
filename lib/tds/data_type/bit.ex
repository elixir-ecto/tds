defmodule Tds.DataType.Bit do
  use Tds.DataType,
    id: 0x32,
    type: :bit,
    name: "Bit"

  alias Tds.Parameter
  alias Tds.DataType.BitN

  @valid_values [nil, true, false, 1, 0]

  def declare(%Parameter{type: :bit}) do
    {:ok, [name()]}
  end

  def declare(param),
    do: {:error, "`#{inspect(param)}` is not valid #{inspect(type())}"}

  def encode_type_info(%Parameter{type: :bit}) do
    {:ok, <<BitN.id()::unsigned-integer-size(8), 1::unsigned-integer-size(8)>>}
  end

  def encode_type_info(param) do
    {:error, "#{inspect(param)} is not of `#{inspect(type())}` type"}
  end

  @doc """
  Encodes parameter data to tds protocol binary format.

  Valid parameter values are `nil`, `true`, `false`, `1`, `0`
  """
  def encode_data(%Parameter{type: :bit, value: value}) do
    cond do
      is_nil(value) ->
        {:ok, <<0::unsigned-integer-size(8)>>}

      value in [true, 1] ->
        {:ok, <<1::unsigned-integer-size(8), 1::unsigned-integer-size(8)>>}

      value in [false, 0] ->
        {:ok, <<1::unsigned-integer-size(8), 0::unsigned-integer-size(8)>>}
    end
  end

  def validate(value) when value in @valid_values, do: :ok

  def validate(value) do
    {:error,
     "Only #{inspect(@valid_values)} are valid :bit values, got `#{
       inspect(value)
     }`"}
  end
end
