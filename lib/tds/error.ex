defmodule Tds.Error do
  @moduledoc """
  Defines the `Tds.Error` struct.

  The struct has two fields:

  * `:message`: expected to be a string
  * `:mssql`: expected to be a keyword list with the fields `line_number`,
              `number` and `msg_text`

  ## Usage

      iex> raise Tds.Error
      ** (Tds.Error) An error occured.

      iex> raise Tds.Error, "some error"
      ** (Tds.Error) some error

      iex> raise Tds.Error, line_number: 10, number: 8, msg_text: "some error"
      ** (Tds.Error) Line 10 (8): some error
  """

  @type error_details :: %{line_number: integer(), number: integer(), msg_text: String.t()}
  @type t :: %__MODULE__{message: String.t(), mssql: error_details}


  defexception [:message, :mssql]

  def exception(message) when is_binary(message) or is_atom(message) do
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
    "Line #{mssql[:line_number]} (Error #{mssql[:number]}): #{mssql[:msg_text]}"
  end

  def message(%__MODULE__{message: message}) when is_binary(message) do
    message
  end

  @external_resource errcodes_path = Path.join(__DIR__, "errors.csv")

  errcodes =
    for line <- File.stream!(errcodes_path) do
      [type, code, regex] = String.split(line, ",", trim: true)
      type = String.to_atom(type)
      code = code |> String.trim()
      regex = String.replace_trailing(regex, "\n", "")

      if code == nil do
        raise CompileError, "Error code must be integer value"
      end

      {code, {type, regex}}
    end

  Enum.group_by(errcodes, &elem(&1, 0), &elem(&1, 1))
  |> Enum.map(fn {code, type_regexes} ->
    {error_code, ""} = Integer.parse(code)

    def get_constraint_violations(unquote(error_code), message) do
      constraint_checks =
        Enum.map(unquote(type_regexes), fn {key, val} ->
          {key, Regex.compile!(val)}
        end)

      extract = fn {key, test}, acc ->
        concatenate_match = fn [match], acc -> [{key, match} | acc] end

        case Regex.scan(test, message, capture: :all_but_first) do
          [] -> acc
          matches -> Enum.reduce(matches, acc, concatenate_match)
        end
      end

      Enum.reduce(constraint_checks, [], extract)
    end
  end)

  def get_constraint_violations(_, _) do
    []
  end
end

defmodule Tds.ConfigError do
  defexception message: "Tds configuration error."

  def exception(message) when is_binary(message) or is_atom(message) do
    %__MODULE__{message: message}
  end
end
