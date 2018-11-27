defmodule Tds.Types.VarChar do
  @moduledoc """
  Wrapps erlang string into structure which TDS undestends
  and can encode this value into varchar type
  """
  @doc "Returns :varchar atom, so we can use :varchar type in migration files"
  def type(), do: :varchar

  def cast(value) do
    {:ok, value}
  end

  def load(value) do
    {:ok, value}
  end

  def dump(value) when is_binary(value) do
    {:ok, {value, :varchar}}
  end
end
