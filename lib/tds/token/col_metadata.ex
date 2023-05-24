defmodule Tds.Token.ColMetadata do
  @moduledoc """
  Decodes the COLMETADATA from TDS packet data token stream. Describes
  result set for interpretation of the following ROW data stream tokens.

  The token value is 0x81 for COLMETADATA token stream. All COLMETADATA data
  streams are grouped together in a single packet.
  """
  alias Tds.Token.ColumnData

  @typedoc """
  Decoded COLMETADATA token stream.

  ## Fields
  - `count` - number of columns in the result set
  - `columndata` - list of `ColumnData.t()` representing columns in the result set
  - `no_metadata` - if `true`, the result set has no metadata
  """
  @type t :: %__MODULE__{
          count: integer(),
          columndata: [ColumnData.t()],
          no_metadata: boolean()
        }

  defstruct count: 0,
            columndata: [],
            no_metadata: false


  @doc """
  Decodes COLMETADATA token stream.

  It finds the number of columns in COLMETADATA token stream and decodes
  each column data.
  """
  def decode(
        <<
          count::little-size(2)-unit(8),
          rest::binary
        >>,
        decoded_token_stream
      ) do
    columndata = ColumnData.decode(count, rest, [])
    no_metadata = if(count == 0, do: true, else: false)

    decoded = %__MODULE__{
      count: count,
      columndata: columndata,
      no_metadata: no_metadata
    }

    [decoded | decoded_token_stream]
  end
end
