defmodule Tds.ResponseTooLargeError do
  @moduledoc """
  Returned when a response grows past the `:max_response_bytes` connection
  option.

  * `:limit`: the configured `:max_response_bytes`
  * `:received`: bytes read for the response when the driver stopped reading,
    packet headers included

  The rest of the response is left unread, so the connection is closed.
  """

  @type t :: %__MODULE__{
          limit: pos_integer(),
          received: pos_integer(),
          message: String.t()
        }

  defexception [:limit, :received, :message]

  @impl true
  def exception(opts) do
    limit = Keyword.fetch!(opts, :limit)

    %__MODULE__{
      limit: limit,
      received: Keyword.fetch!(opts, :received),
      message: "response exceeded max_response_bytes (limit #{limit} bytes)"
    }
  end
end
