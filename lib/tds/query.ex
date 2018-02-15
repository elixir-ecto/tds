defmodule Tds.Query do
  alias Tds.Parameter
  alias Tds.Types

  defstruct [:statement, :handle]

  defimpl DBConnection.Query, for: Tds.Query do
    def encode(_statement, [], _opts) do
      []
    end

    def encode(
          %Tds.Query{
            statement: statement,
            handle: handle
          } = _,
          params,
          _opts
        ) do
      case handle do
        nil ->
          param_desc =
            params
            |> Enum.map(fn %Parameter{} = param ->
                 Types.encode_param_descriptor(param)
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

    def decode(_query, results, opts) do
      mapper = opts[:decode_mapper] || fn x -> x end
      results =
        results
        |> Enum.map(fn %Tds.Result{rows: rows} = result ->
          rows = do_decode(rows, mapper, [])
          %Tds.Result{result | rows: rows}
        end)
      if Keyword.get(opts, :multiple_datasets) do
        results
      else
        List.first(results) || %Tds.Result{num_rows: 0, rows: [], columns: []}
      end
    end

    def do_decode([row | rows], mapper, decoded) do
      decoded = [mapper.(row) | decoded]
      do_decode(rows, mapper, decoded)
    end

    def do_decode(nil, _, _) do
      # this case is required because struct/8 in ecto/adapters/sql.ex:541
      # specifically checks for %{rows: nil, num_rows: 1}
      # thus treating rows: [] as an error
      nil
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
