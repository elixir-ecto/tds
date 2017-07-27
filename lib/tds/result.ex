defmodule Tds.Result do
  @moduledoc """
  Result struct returned from any successful query. Its fields are:

    * `columns` - The column names;
    * `rows` - The result set. A list of tuples, each tuple corresponding to a
               row, each element in the tuple corresponds to a column;
    * `num_rows` - The number of fetched or affected rows;
  """

  @type t :: %__MODULE__{
    columns:  [String.t] | nil,
    rows:     [tuple] | nil,
    num_rows: integer}

  defstruct [:command, :columns, :rows, :num_rows]
end
