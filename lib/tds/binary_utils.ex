defmodule Tds.BinaryUtils do
  @moduledoc false
  @on_load :load_nifs

  def load_nifs() do
    path = :filename.join(:code.priv_dir(:tds), 'binaryutils')
    :ok = :erlang.load_nif(path, 0)
  end

  @spec convert(from_encoding :: String.t, to_encoding :: String.t, binary) :: binary
  def convert(_from_encoding, _to_encoding, _binary) do
    raise "NIF binaryutils is not implemented"
  end

  defmacro int64 do
    quote do: signed - 64
  end

  defmacro int32 do
    quote do: signed - 32
  end

  defmacro int16 do
    quote do: signed - 16
  end

  defmacro uint16 do
    quote do: unsigned - 16
  end

  defmacro int8 do
    quote do: signed - 8
  end

  defmacro float64 do
    quote do: float - 64
  end

  defmacro float32 do
    quote do: float - 32
  end

  defmacro binary(size) do
    quote do: binary - size(unquote(size))
  end

  defmacro binary(size, unit) do
    quote do: binary - size(unquote(size)) - unit(unquote(unit))
  end

  defmacro unicode(size) do
    quote do: little - binary - size(unquote(size)) - unit(16)
  end
end
