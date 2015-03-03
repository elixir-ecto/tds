defmodule Tds.Parameter do
  @type t :: %__MODULE__{
    name:       String.t | nil,
    direction:  Atom | :input
  }
  defstruct [name: "", direction: :input, value: "", type: nil]

  def option_flags(%__MODULE__{direction: direction, value: value}) do
    
    case direction do
      :output -> fByRefValue = 1
      _ -> fByRefValue = 0
    end

    case value do
      :default -> fDefaultValue = 1
      _ -> fDefaultValue = 0
    end

    <<0::size(6), fByRefValue::size(1), fDefaultValue::size(1)>>
  end
end