defmodule Tds.Type do
  @moduledoc """
  Behaviour for TDS type handlers.

  Each handler serves one or more TDS type codes and provides
  encode/decode between TDS wire format and Elixir values.
  """

  @type metadata :: map()

  @doc "TDS type codes this handler serves (decode path)."
  @callback type_codes() :: [byte()]

  @doc "Atom type names this handler serves (encode path)."
  @callback type_names() :: [atom()]

  @doc "Parse type-specific metadata from token stream binary."
  @callback decode_metadata(binary()) ::
              {:ok, metadata(), rest :: binary()}

  @doc """
  Decode raw value bytes into Elixir value.

  Receives `nil` for SQL NULL (DataReader detected null marker).
  Receives raw bytes with length prefix already stripped
  by DataReader.
  """
  @callback decode(nil | binary(), metadata()) :: term()

  @doc """
  Encode Elixir value to TDS binary for RPC parameter.

  Returns `{type_code, colmetadata_binary, value_binary}`.
  """
  @callback encode(term(), metadata()) ::
              {type_code :: byte(), meta_bin :: iodata(), value_bin :: iodata()}

  @doc "Generate sp_executesql parameter descriptor string."
  @callback param_descriptor(term(), metadata()) :: String.t()

  @doc """
  Type inference: can this handler encode this value?

  Returns `{:ok, metadata}` if yes, `:skip` if not this
  handler's type.
  """
  @callback infer(term()) :: {:ok, metadata()} | :skip
end
