defmodule Tds.Error do
  @moduledoc """
  Defines the `Tds.Error` struct.

  The struct has to fields:

  * `:message`: expected to be a string
  * `:mssql`: expected to be a keyword list with the fields `line_number`,
              `number` and `msg_text`

  ## Usage

      iex> raise Tds.Error
      ** (Tds.Error) An error occured.

      iex> raise Tds.Error, "some error"
      ** (Tds.Error) some error

      iex> raise Tds.Error, "some error"
      ** (Tds.Error) some error

      iex> raise Tds.Error, line_number: 10, number: 8, msg_text: "some error"
      ** (Tds.Error) Line 10 (8): some error
  """

  defexception [:message, :mssql]

  @spec exception(String.t() | keyword) :: %__MODULE__{}
  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def exception(line_number: line_number, number: number, msg_text: msg) do
    %__MODULE__{
      mssql: %{
        line_number: line_number,
        number: number,
        msg_text: msg
      }
    }
  end

  def exception(_) do
    %__MODULE__{message: "An error occured."}
  end

  @spec message(%__MODULE__{}) :: String.t()
  def message(%__MODULE__{mssql: mssql}) when is_map(mssql) do
    "Line #{mssql[:line_number]} (#{mssql[:number]}): #{mssql[:msg_text]}"
  end

  def message(%__MODULE__{message: message}) when is_binary(message) do
    message
  end
end
