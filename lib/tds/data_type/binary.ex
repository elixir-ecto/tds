defmodule Tds.DataType.Binary do
  import Bitwise
  require Logger

  use Tds.DataType,
    id: 0xAD,
    type: :binary,
    name: "Binary",
    data_length_length: 2,
    max_length: 8000

  alias Tds.Parameter

  @null (1 <<< 16) - 1

  def declare(%Parameter{} = param) do
    case param do
      %{type: :binary, direction: direction}
      when direction != :output ->
        len = Integer.to_string(resolve_length(param))
        {:ok, [name(), ?(, len, ?)]}

      %{type: :binary, value: value} when is_nil(value) or value == <<>> ->
        {:ok, [name(), ?(, "1", ?)]}

      %{type: :binary, value: _} ->
        len = Integer.to_string(max_length())
        {:ok, [name(), ?(, len, ?)]}

      _ ->
        {:error, "`#{param}` is not of :binary type"}
    end
  end

  def encode_type_info(%Parameter{type: :binary, value: value} = param) do
    case value || <<>> do
      <<>> ->
        {:ok,
         <<id()::unsigned-integer-size(8),
           @null::little-unsigned-integer-size(8)-unit(2)>>}

      _ ->
        len = min(max_length(), resolve_length(param)) * 8

        {:ok,
         <<id()::unsigned-integer-size(8),
           @null::little-unsigned-integer-size(len)>>}
    end
  end

  def encode_data(%Parameter{type: :binary, value: value}) do
    case value || <<>> do
      <<>> ->
        {:ok, <<@null::little-unsigned-integer-size(8)-unit(2)>>}

      val ->
        len = byte_size(value || <<>>)

        if max_length() > len do
          Logger.warn(fn ->
            "Binary value will be truncated to max #{max_length()} bytes"
          end)
        end

        len = min(max_length(), len) * 8

        {:ok, <<len::little-unsigned-integer-size(8)-unit(2), val::size(len)>>}
    end
  end

  @spec validate(any) :: :ok | {:error, any}
  def validate(value) when is_nil(value) or is_binary(value), do: :ok
  def validate(%Parameter{type: :bit, value: value}), do: validate(value)
  def validate(value), do: {:error, "Invalid Bit value #{inspect(value)}"}

  @spec resolve_length(Tds.Parameter.t()) :: non_neg_integer
  defp resolve_length(%Parameter{value: value}) do
    case value || <<>> do
      <<>> -> 1
      val -> byte_size(val) * 1
    end
  end
end
