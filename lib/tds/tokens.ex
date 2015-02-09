defmodule Tds.Tokens do
  import Tds.BinaryUtils
  import Tds.Utils

  alias Tds.Types

  require Logger

  @tds_token_returnstatus   0x79 # 0x79
  @tds_token_colmetadata    0x81 # 0x81
  @tds_token_order          0xA9 # 0xA9
  @tds_token_error          0xAA # 0xAA
  @tds_token_info           0xAB # 0xAB
  @tds_token_loginack       0xAD # 0xAD
  @tds_token_row            0xD1 # 0xD1
  @tds_token_nbcrow         0xD2 # 0xD1
  @tds_token_envchange      0xE3 # 0xE3
  @tds_token_sspi           0xED # 0xED
  @tds_token_done           0xFD # 0xFD
  @tds_token_doneproc       0xFE # 0xFE
  @tds_token_doneinproc     0xFF # 0xFF

  @tds_envtype_database       1
  @tds_envtype_language       2
  @tds_envtype_charset        3
  @tds_envtype_packetsize     4
  @tds_envtype_begintrans     8
  @tds_envtype_committrans    9
  @tds_envtype_rollbacktrans  10


  ## Decode Token Stream
  def decode_tokens(tail, tokens) when tail == "" or tail == nil, do: tokens
  def decode_tokens(<<tail::binary>>, tokens) do
    {tokens, tail} = decode_token(tail, tokens)
    decode_tokens(tail, tokens)
  end


  # COLMETADATA
  defp decode_token(<<@tds_token_colmetadata, column_count::little-2*8, tail::binary>>, tokens) do
    columns = []
    {columns, tail} = decode_columns(tail, columns, column_count)
    {[columns: columns]++tokens, tail}
  end

  # ERROR
  defp decode_token(<<@tds_token_error, length::little-size(16), number::little-size(32), state, class,
      msg_len::little-size(16), msg::binary-size(msg_len)-unit(16),
      sn_len, server_name::binary-size(sn_len)-unit(16),
      pn_len, proc_name::binary-size(pn_len)-unit(16),
      line_number::little-size(32),
      _data::binary>>, _tokens) do

    e = %{
      length: length,
      number: number,
      state: state,
      class: class,
      msg_text: ucs2_to_utf(msg),
      server_name: ucs2_to_utf(server_name),
      proc_name: ucs2_to_utf(proc_name),
      line_number: line_number,
    }
    Logger.info "ERROR MESSAGE: #{e.msg_text}"
    {[error: e], nil}
  end

  defp decode_token(<<@tds_token_info, length::little-size(16), number::little-size(32), state, class,
      msg_len::little-size(16), msg::binary-size(msg_len)-unit(16),
      sn_len, server_name::binary-size(sn_len)-unit(16),
      pn_len, proc_name::binary-size(pn_len)-unit(16),
      line_number::little-size(32),
      tail::binary>>, _tokens) do
    i = %{
      length: length,
      number: number,
      state: state,
      class: class,
      msg_text: ucs2_to_utf(msg),
      server_name: ucs2_to_utf(server_name),
      proc_name: ucs2_to_utf(proc_name),
      line_number: line_number,
    }
    Logger.info "INFO MESSAGE: #{i.msg_text}"
    {[info: i], tail}
  end


  ## ROW
  defp decode_token(<<@tds_token_row, tail::binary>>, tokens) do
    column_count = Enum.count tokens[:columns]
    {row, tail} = decode_row_columns(tail, tokens, {}, column_count, 0)

    tokens = Keyword.update(tokens, :rows, [row], fn(_x) -> [row|tokens[:rows]] end)
    {tokens, tail}
  end

  ## NBC ROW
  defp decode_token(<<@tds_token_nbcrow, tail::binary>>, tokens) do
    column_count = Enum.count tokens[:columns]
    {bitmap_bytes, _} = column_count / 8
      |> Float.ceil
      |> Float.to_char_list([decimals: 0])
      |> to_string
      |> Integer.parse

    {bitmap, tail} = bitmap_list(tail, bitmap_bytes)
    bitmap = bitmap |> Enum.reverse
    {row, tail} = decode_row_columns(tail, tokens, {}, column_count, 0, bitmap)

    tokens = Keyword.update(tokens, :rows, [row], fn(_x) -> [row|tokens[:rows]] end)
    {tokens, tail}
  end

  defp decode_token(<<@tds_token_envchange, length::little-unsigned-16, env_type::unsigned-8, tail::binary>> = data, tokens) do
    #Logger.info "EnvChange: #{Tds.Utils.to_hex_string data}"
    token = case env_type do
      @tds_envtype_database ->
        <<new_value_size::unsigned-8, 
          new_value::binary-little-size(new_value_size)-unit(8), 
          old_value_size::unsigned-8, 
          old_value::binary-little-size(old_value_size)-unit(8), 
          tail::binary>> = tail
      @tds_envtype_packetsize ->
        <<new_value_size::unsigned-8, 
          new_value::binary-little-size(new_value_size)-unit(8), 
          old_value_size::unsigned-8, 
          old_value::binary-little-size(old_value_size)-unit(8), 
          tail::binary>> = tail
      @tds_envtype_begintrans ->
        <<value_size::unsigned-8, new_value::binary-little-size(value_size)-unit(8), 0x00, tail::binary>> = tail
        #Logger.info "Begin Transaction: #{Tds.Utils.to_hex_string new_value}"
        [trans: new_value]
      @tds_envtype_committrans ->
        <<0x00, value_size::unsigned-8, old_value::binary-little-size(value_size)-unit(8), tail::binary>> = tail
        #Logger.info "Commit Transaction"
        [trans: <<0x00>>]
      @tds_envtype_rollbacktrans ->
        <<0x00, value_size::unsigned-8, old_value::binary-little-size(value_size)-unit(8), tail::binary>> = tail
        #Logger.info "Rollback Transaction"
        [trans: <<0x00>>]
    end
    #IO.inspect token ++ tokens
    {token ++ tokens, tail}
  end

  ## DONE
  defp decode_token(<<@tds_token_done, status::int16, cur_cmd::binary(2), row_count::little-size(8)-unit(8), _tail::binary>>, tokens) do
    #Logger.info "Done Row Count: #{row_count}"
    #IO.inspect tokens
    case tokens do
      [done: done] -> 
        
        cond do
          row_count > done.rows -> {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++ tokens, nil}
          true -> {tokens, nil}
        end
        {tokens, nil}
      _ ->  {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++ tokens, nil}
    end
  end

  ## DONEPROC
  defp decode_token(<<@tds_token_doneproc, status::int16, cur_cmd::binary(2), row_count::little-size(8)-unit(8), tail::binary>>, tokens) do
    #Logger.info "Done Proc Row Count: #{row_count}"
    #IO.inspect tokens
    case tokens do
      [done: done] -> 
        #Logger.info "Matched"
        cond do
          row_count > done.rows -> {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++ tokens, nil}
          true -> {tokens, nil}
        end
        {tokens, nil}
      _ ->  {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++ tokens, nil}
    end
  end

  ## DONEINPROC
  defp decode_token(<<@tds_token_doneinproc, status::int16, cur_cmd::binary(2), row_count::little-size(8)-unit(8), _something::binary-size(5), tail::binary>>, tokens) do
    #Logger.info "Done In Proc Count: #{row_count}"
    #IO.inspect tokens
    case tokens do
      [done: done] -> 
        #Logger.info "Matched"
        cond do
          row_count > done.rows -> {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++ tokens, nil}
          true -> {tokens, nil}
        end
        {tokens, nil}
      _ ->  {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++ tokens, nil}
    end
  end


  ## Row and Column Decoders

  defp bitmap_list(bitmap, <<tail::binary>>, n) when n <= 0 do
    {bitmap, tail}
  end
  defp bitmap_list(bitmap \\ [], <<byte::binary-size(1)-unit(8), tail::binary>>, n) when n > 0 do
    list = for <<bit::1 <- byte>>, do: bit
    bitmap_list(list ++ bitmap, tail, n - 1)
  end

  defp decode_columns(<<tail::binary>>, columns, n) when n < 1 do
    {Enum.reverse(columns), tail}
  end

  defp decode_columns(<<tail::binary>>, columns, n) do
    {column, tail} = decode_column(tail)
    decode_columns(tail, [column | columns], n - 1)
  end

  defp decode_column(<<_usertype::int32, _flags::int16, tail::binary>> = data) do


    #data_type = Enum.find(Types.data_types, fn(x) -> x[:byte] == <<type>> end)
    #Logger.debug "Decode Data Type: #{Tds.Utils.to_hex_string data}"
    Logger.debug "Decode Column: #{Tds.Utils.to_hex_string tail}"
    {info, tail} = Types.decode_info(tail)
    {name, tail} = decode_column_name(tail)
    info
      |> Map.put(:name, name)
    {info, tail}
  end

  defp decode_column_name(<<name_length::int8, name::unicode(name_length), tail::binary>>) do
    name = name |> :unicode.characters_to_binary({:utf16, :little}, :utf8)
    {name, tail}
  end

  defp decode_row_columns(<<tail::binary>>, _tokens, row, column_count, n) when n >= column_count do
    {row, tail}
  end

  defp decode_row_columns(<<tail::binary>>, tokens, row, column_count, n) do
    {:ok, column} = Enum.fetch(tokens[:columns], n)
    {value, tail} = decode_row_column(tail, column)
    row = Tuple.insert_at(row, tuple_size(row), value)
    decode_row_columns(tail, tokens, row, column_count, n + 1)
  end

  defp decode_row_columns(<<tail::binary>>, _tokens, row, column_count, n, _bitmap) when n >= column_count do
    {row, tail}
  end

  defp decode_row_columns(<<tail::binary>>, tokens, row, column_count, n, bitmap) do

    case Enum.fetch(bitmap, n) do
      {:ok, 0} ->
        {:ok, column} = Enum.fetch(tokens[:columns], n)
        {value, tail} = decode_row_column(tail, column)
        row = Tuple.insert_at(row, tuple_size(row), value)
        decode_row_columns(tail, tokens, row, column_count, n + 1, bitmap)
      {_, _} ->
        row = Tuple.insert_at(row, tuple_size(row), nil)
        decode_row_columns(tail, tokens, row, column_count, n + 1, bitmap)
    end
  end

  defp decode_row_column(<<tail::binary>>, column) do
    #data_type = column[:data_type_code]
    #Logger.debug "Decode Row Column: #{Tds.Utils.to_hex_string tail}"
    Types.decode_data(column, tail)
  end

end