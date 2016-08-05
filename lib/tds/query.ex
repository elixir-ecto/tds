defmodule Tds.Query do
  alias Tds.Parameter

  defstruct [:statement, :handle]

  defimpl DBConnection.Query, for: Tds.Query do
    def encode(statement, [], opts) do
      []
    end
    def encode(%Tds.Query{statement: statement, handle: handle}, params, opts) do
      case handle do
        nil ->
          param_desc = params |> Enum.map(fn(%Parameter{} = param) ->
            Tds.Types.encode_param_descriptor(param)
          end)

          param_desc = param_desc
          |> Enum.join(", ")

          [%Parameter{value: statement, type: :string},
           %Parameter{value: param_desc, type: :string}] ++ params
        _ ->
          params
      end
    end

    def decode(query, result, opts) do
      result
    end

    def parse(params, _) do
      params
    end

    def describe(query, _) do
      query
    end
  end

  defimpl String.Chars, for: Tds.Query do
    def to_string(%Tds.Query{statement: statement}) do
      IO.iodata_to_binary(statement)
    end
  end
end
