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
          rows: [tuple],
          num_rows: integer
        }

  defstruct columns: nil, rows: [], num_rows: 0
end
