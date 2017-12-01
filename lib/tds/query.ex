defmodule Tds.Query do
  alias Tds.Parameter

  defstruct [:statement, :handle]

  defimpl DBConnection.Query, for: Tds.Query do
    def encode(_statement, [], _opts) do
      []
    end

    def encode(
          %Tds.Query{
            statement: statement,
            handle: handle
          },
          params,
          _opts
        ) do
      case handle do
        nil ->
          param_desc =
            params
            |> Enum.map(fn %Parameter{} = param ->
                 Tds.Types.encode_param_descriptor(param)
               end)

          param_desc =
            param_desc
            |> Enum.join(", ")

          [
            %Parameter{value: statement, type: :string},
            %Parameter{value: param_desc, type: :string}
          ] ++ params

        _ ->
          params
      end
    end

    def decode(_query, result, opts) do
      mapper = opts[:decode_mapper] || fn x -> x end
      %Tds.Result{rows: rows} = result
      rows = do_decode(rows, mapper, [])
      %Tds.Result{result | rows: rows}
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
    def to_string(%Tds.Query{statement: statement}) do
      IO.iodata_to_binary(statement)
    end
  end
end
