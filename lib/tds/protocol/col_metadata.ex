defmodule Tds.Protocol.ColMetadata do
  @moduledoc """
  Parses the column metadata from TDS response.
  """
  alias Tds.Protocol.ColMetadata

  @type t :: %__MODULE__{
          user_type: nil | integer,
          flags: nil | integer,
          data_type: nil | integer,
          length: nil | integer,
          column_name: nil | binary
        }

  defstruct user_type: nil,
            flags: nil,
            data_type: nil,
            length: nil,
            column_name: nil

  @spec parse(binary) :: [ColMetadata.t()]
  def parse(<<0x81, column_count::16-little, rest::binary>>) do
    process_columns(column_count, rest, [])
  end

  defp process_columns(0, _rest, acc), do: Enum.reverse(acc)

  defp process_columns(
         column_count,
         <<user_type::32-little, flags::16-little, data_type::8, rest::binary>>,
         acc
       ) do
    {column_info, remaining_binary} = process_column(user_type, flags, data_type, rest)
    process_columns(column_count - 1, remaining_binary, [column_info | acc])
  end

  # IMAGE data type
  defp process_column(
         user_type,
         flags,
         0x22,
         <<length::little-unsigned-32, column_name_length::unsigned-8,
           column_name::binary-unit(16)-size(column_name_length), rest::binary>>
       ) do
    column_name = decode_column_name(column_name)

    {
      %{
        user_type: user_type,
        flags: flags,
        data_type: :image,
        length: length,
        column_name: column_name
      },
      rest
    }
  end

  defp decode_column_name(column_name) do
    column_name
    |> Tds.Encoding.UCS2.to_string()
  end
end
