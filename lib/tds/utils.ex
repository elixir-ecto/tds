defmodule Tds.Utils do
  @moduledoc false
  require Logger

  def to_hex_list(x) when is_list(x) do
    Enum.map(x, &Base.encode16(<<&1>>))
  end

  def to_hex_list(x) when is_binary(x) do
    x
    |> :erlang.binary_to_list()
    |> to_hex_list()
  end

  def to_hex_string(x) when is_binary(x) do
    x
    |> to_hex_list()
    |> to_hex_string()
  end

  def to_hex_string(x) when is_list(x) do
    Enum.join(x, " ")
  end

  def to_little_ucs2(str) do
    convert = fn char ->
      case :iconv.convert("UTF-8", "UCS-2LE", <<char::utf8>>) do
        "" -> <<63::little-size(8)-unit(2)>>
        c -> c
      end
    end

    for <<ch::utf8 <- str>>,
      do: convert.(ch),
      into: <<>>
  end

  def ucs2_to_utf(s) do
    for <<ch::little-size(8)-unit(2) <- s>>,
      do: :iconv.convert("UCS-2BE", "UTF-8", <<ch::utf16>>),
      into: <<>>
  end

  def to_boolean(<<1>>) do
    true
  end

  def to_boolean(<<0>>) do
    false
  end

  def error(error, _s) do
    {:error, error}
  end

  if Kernel.function_exported?(Decimal, :from_float, 1) do
    def to_decimal(float), do: Decimal.from_float(float)
  else
    def to_decimal(float), do: Decimal.new(float)
  end
end
