defmodule Tds.DataType.BigInt do
  use Tds.DataType,
    id: 0x7F,
    type: :bigint,
    type: "BigInt"

  alias Tds.Parameter
  alias Tds.DataType.IntN

  @max_value 9_223_372_036_854_775_807
  @min_value -9_223_372_036_854_775_808

  @impl Tds.DataType
  @spec declare(Tds.Parameter.t()) :: {:ok, list(String.t())} | {:error, any}
  def declare(%Parameter{type: :bigint}), do: {:ok, [name()]}

  def declare(param),
    do: {:error, "`#{inspect(param)}` is not valid #{inspect(type())}"}

  @impl Tds.DataType
  @spec encode_type_info(Tds.Parameter.t()) :: {:ok, binary} | {:error, any}
  def encode_type_info(%Parameter{type: :bigint}) do
    {:ok, <<IntN.id()::unsigned-integer-8, 8::unsigned-integer-8>>}
  end

  def encode_type_info(param) do
    {:error, "#{inspect(param)} is not of `#{inspect(type())}` type"}
  end

  @impl Tds.DataType
  @spec encode_data(Tds.Parameter.t()) ::
          {:ok, <<_::8, _::_*64>>} | {:error, any}
  def encode_data(%Parameter{} = param) do
    case param do
      %{type: :bigint, value: nil} ->
        {:ok, <<0::unsigned-integer-8>>}

      %{type: :bigint, value: value} ->
        {:ok,
         <<8::unsigned-integer-8, value::little-signed-integer-size(8)-unit(8)>>}

      _ ->
        {:error, "`#{inspect(param)}` is not :bigint type"}
    end
  end

  @impl Tds.DataType
  @spec validate(any) :: :ok | {:error, any}
  def validate(value) when is_nil(value) or is_integer(value) do
    case value do
      nil ->
        :ok

      value when value >= @min_value and value <= @max_value ->
        :ok

      _ ->
        {:error,
         "Value #{value} is not in `BigInt` type range #{@min_value}..#{
           @max_value
         }"}
    end
  end

  def validate(%Parameter{type: :bigint, value: value}), do: validate(value)

  def validate(value), do: {:error, "Invalid BigInt value #{inspect(value)}"}
end
