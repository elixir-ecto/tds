defmodule Tds.DataType do
  @moduledoc """
  An behaviour for Sql Data Types
  """

  @doc """
  When implmented generates parameter type declaration used in sql prepare or
  execute statement.
  """
  @callback declare(param :: Tds.Parameter.t()) ::
              {:ok, list(String.t())} | {:error, any}
  @doc """
  When implemented encodes `TYPE_INFO`
  """
  @callback encode_type_info(param :: Tds.Parameter.t()) ::
              {:ok, binary} | {:error, any}

  @doc """
  When implmented encodes parameter into
  """
  @callback encode_data(param :: Tds.Parameter.t()) ::
              {:ok, binary} | {:error, any}

  @callback validate(value :: any) :: :ok | {:error, any}

  @doc """
  When implemented, resolves parameter value length for given type
  """
  @callback resolve_length(value :: any) :: non_neg_integer

  @optional_callbacks resolve_length: 1

  defmacro __using__(opts) do
    quote do
      @behaviour Tds.DataType

      @opts unquote(opts)
      @default_type __MODULE__
                    |> Module.split()
                    |> List.last()
                    |> String.downcase()
                    |> String.to_atom()
      @default_name __MODULE__ |> Module.split() |> List.last()

      @doc """
      Returns TDS protocol token id for data type.

      For `#{inspect(Keyword.get(@opts, :type))}` token is `0x#{
        Keyword.get(@opts, :id) |> Integer.to_string(16)
      }`
      """
      @spec id() :: integer
      def id(), do: Keyword.get(@opts, :id)

      @doc """
      Returns atom `#{inspect(Keyword.get(@opts, :type))}` as data type that can be used
      in prameters. Exception are types like `:intn`, `:bitn` since they are generalised
      version of data types that inherits it.
      """
      def type(), do: Keyword.get(@opts, :type, @default_type)

      @doc """
      Name of the type, should match module name without namespace.
      """
      def name() do
        Keyword.get(@opts, :name, @default_name)
      end

      def data_length_length(), do: Keyword.get(@opts, :data_length_length)

      @spec max_length() :: integer
      def max_length(), do: Keyword.get(@opts, :max_length)

      @spec has_collation?() :: boolean
      def has_collation?(), do: Keyword.get(@opts, :has_collation, false)
    end
  end
end
