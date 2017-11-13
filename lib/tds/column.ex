defmodule Tds.Column do
  @type t :: %__MODULE__{
    name: String.t | nil,
    type: Atom | nil,
    opts: Keyword.t
  }

  defstruct [name: "", type: nil, opts: []]
end
