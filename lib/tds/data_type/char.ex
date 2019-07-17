defmodule Tds.DataType.Char do
  alias Tds.Parameter

  use Tds.DataType,
    id: 0xAF,
    type: :char,
    name: "Char",
    has_collation: true,
    data_length_length: 2,
    max_length: 8_000

  @spec declare(Tds.Parameter.t()) ::
          {:ok, list(String.t())}
          | {:error, String.t()}
  def declare(%Parameter{type: :char, length: length, value: value} = param) do
    cond do
      length > 1 and length <= 8_000 ->
        {:ok, [name(), ?(, Integer.to_string(length), ?)]}

      is_integer(length) ->
        {:error,
         "Invalid `:char` length #{length}, must be in range [1..8_000]"}

      value in [nil, "", ''] ->
        {:ok, [name(), "(1)"]}

      is_binary(value) ->
        {:ok, [name(), ?(, Integer.to_string(length), ?)]}

      is_list(value) ->
        length =
          value
          |> String.Chars.to_string()
          |> String.length()

        {:ok, [name(), ?(, Integer.to_string(length), ?)]}

      true ->
        {:error, "Parameter length unkonwn, #{inspect(param)}"}
    end
  end

  def encode_type_info(%Parameter{type: :char}=param) do

  end
  defmodule A do
    def decode(input) do
      # convert = fn x ->
      #   <<ch::utf16>> = :iconv.convert("CP1252", "UTF-8", x)
      #   case <<ch::utf8>> do
      #     "" -> "?"
      #     c -> c
      #   end
      # end
      for <<ch::little-size(16) <- input>>, do: <<ch::utf8>>, into: ""
    end
  end

  def validate(value) when is_nil(value), do: :ok

  def validate(value) when is_binary(value) do
    if String.valid?(value),
      do: :ok,
      else: {:error, "value #{inspect(value)} contains invalid chars"}
  end

  def validate(value) when is_list(value) do
    value
    |> String.Chars.to_string()
    |> validate()
  end

  def validate(value) do
    {:error, "value #{inspect(value)} contains invalid string"}
  end

  def resolve_length(%Parameter{type: :char, length: length, value: value}) do
    cond do
      length > 0 and length <= 8_000 -> length
      value in ["", ''] -> 1
      is_list(value) -> value |> String.Chars.to_string() |> String.length()
      is_binary(value) -> String.length(value)
      true -> max_length()
    end
  end
end
