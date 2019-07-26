defmodule Tds.Query do
  @moduledoc false

  @type t :: %__MODULE__{
    statement: String.t,
    handle: term
  }

  defstruct [:statement, :handle]
end

defimpl DBConnection.Query, for: Tds.Query do
  alias Tds.Parameter
  alias Tds.Types
  alias Tds.Query
  alias Tds.Result

  def encode(_statement, [], _opts) do
    []
  end

  def encode(%Query{handle: nil}, params, _) do
    params
  end

  def encode(%Query{statement: statement}, params, _) do
    param_desc =
      params
      |> Enum.map(&Types.encode_param_descriptor/1)
      |> Enum.join(", ")

    [
      %Parameter{value: statement, type: :string},
      %Parameter{value: param_desc, type: :string}
    ] ++ params
  end

  def decode(_query, %Result{rows: rows} = result, opts) do
    mapper = opts[:decode_mapper] || fn x -> x end
    rows = do_decode(rows, mapper, [])
    %Result{result | rows: rows}
  end

  def do_decode([row | rows], mapper, decoded) do
    decoded = [mapper.(row) | decoded]
    do_decode(rows, mapper, decoded)
  end

  def do_decode(_, _, decoded) do
    decoded
  end

  def parse(params, _) do
    params
  end

  def describe(query, _) do
    query
  end
end

defimpl String.Chars, for: Tds.Query do
  @spec to_string(Tds.Query.t()) :: String.t()
  def to_string(%Tds.Query{statement: statement}) do
    IO.iodata_to_binary(statement)
  end
end
