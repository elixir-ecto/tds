defmodule Tds.Parameter do
  @type t :: %__MODULE__{
    name:       String.t | nil,
    direction:  Atom | :input
  }
  defstruct [name: "", direction: :input, value: "", type: nil, length: nil]

  def option_flags(%__MODULE__{direction: direction, value: value}) do
    fByRefValue =
      case direction do
        :output -> 1
        _ -> 0
      end

    fDefaultValue =
      case value do
        :default -> 1
        _ -> 0
      end

    <<0::size(6), fByRefValue::size(1), fDefaultValue::size(1)>>
  end
end
