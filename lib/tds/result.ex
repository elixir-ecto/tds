defmodule Tds.Result do
  @moduledoc """
  Result struct returned from any successful query.

  ## Fields

  * `columns`: The column names.
  * `rows`: The result set as a list of tuples. Each tuple corresponds to a
    row, while each element in the tuple corresponds to a column.
  * `num_rows`: The number of fetched or affected rows.
  """

  @typedoc "The result of a database query."
  @type t :: %__MODULE__{
          columns: nil | [String.t()],
          rows: nil | [[any()]],
          num_rows: integer
        }

  defstruct columns: nil, rows: nil, num_rows: 0

  if Code.ensure_loaded?(Table.Reader) do
    defimpl Table.Reader, for: Tds.Result do
      def init(%{columns: columns}) when columns in [nil, []] do
        {:rows, %{columns: [], count: 0}, []}
      end

      def init(result) do
        {:rows, %{columns: result.columns, count: result.num_rows}, result.rows}
      end
    end
  end
end
