defmodule Tds.DataType.IntN do
  use Tds.DataType,
    id: 0x26,
    type: :intn,
    name: "IntN",
    data_length_length: 1

  def declare(_), do: raise(RuntimeError, "Not supported")
  def encode_type_info(_), do: raise(RuntimeError, "Not supported")
  def encode_data(_), do: raise(RuntimeError, "Not supported")
  def validate(_), do: raise(RuntimeError, "Not supported")
end
