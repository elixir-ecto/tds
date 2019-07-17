defmodule Tds.SqlType do
  import Bitwise
  @moduledoc """
  Behaviour for Sql Date Type serializer
  """

  @doc """
  Returns an atom used to identify SQL Data Type in tds library
  """
  @callback type() :: atom

  @callback token() :: integer


  @callback is_match?(binary) :: boolean


  @doc """
  When implmented, encodes given value into Sql Data Type binary representation
  """
  @callback encode_data(value :: any, size :: integer, precision :: integer) ::
              {:ok, binary}
              | {:error, any}

  defmacro __using__(type: type, token: token) do
    quote do
      @behaviour Tds.SqlType

      @sql_type unquote(type)
      @token unquote(token)

      @impl true
      def type(), do: @sql_type

      @impl true
      def token(), do: @token

      @impl true
      def is_match?(<<@token, _::binary>>), do: true
      def is_match?(_), do: false


    end
  end

  @types [
    {}
  ]

  def null?(0x1F), do: true
  def null?(_), do: false

  def fixed_length?(token) do
    <<>> = <<token>>
  end


end
