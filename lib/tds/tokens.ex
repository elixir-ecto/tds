defmodule Tds.Tokens do
  import Tds.BinaryUtils
  import Tds.Utils
  import Bitwise

  require Logger

  alias Tds.Types

  # 0x79
  @tds_token_returnstatus 0x79
  # 0x81
  @tds_token_colmetadata 0x81
  # 0xA9
  @tds_token_order 0xA9
  # 0xAA
  @tds_token_error 0xAA
  # 0xAB
  @tds_token_info 0xAB
  @tds_token_returnvalue 0xAC
  @tds_token_loginack 0xAD
  # 0xD1 - ROW
  @tds_token_row 0xD1
  # 0xD2 - NBCROW
  @tds_token_nbcrow 0xD2
  # 0xE3
  @tds_token_envchange 0xE3
  # @tds_token_sspi           0xED # 0xED
  # 0xFD
  @tds_token_done 0xFD
  # 0xFE
  @tds_token_doneproc 0xFE
  # 0xFF
  @tds_token_doneinproc 0xFF

  @tds_envtype_database 1
  # @tds_envtype_language       2
  # @tds_envtype_charset        3
  @tds_envtype_packetsize 4
  @tds_envtype_begintrans 8
  @tds_envtype_committrans 9
  @tds_envtype_rollbacktrans 10
  @tds_envtype_defecttrans 12
  @tds_envtype_mirroring_partner 13
  @tds_envtype_routing 20

  @token_DONE_FINAL 0x0
  @token_DONE_MORE 0x1
  @token_DONE_ERROR 0x2
  @token_DONE_INXACT 0x4
  @token_DONE_COUNT 0x10
  @token_DONE_ATTN 0x20
  @token_DONE_SRVERROR 0x100

  @done_tokens [
    final: @token_DONE_FINAL,
    more: @token_DONE_MORE,
    error: @token_DONE_ERROR,
    inxact: @token_DONE_INXACT,
    count: @token_DONE_COUNT,
    attn: @token_DONE_ATTN,
    srverror: @token_DONE_SRVERROR
  ]
  defp print_status(status) do
    Enum.map(@done_tokens, fn {key, v} ->
      {key, (status &&& v) == v}
    end)
    |> IO.inspect(label: "DONE TOKENS")
  end


  ## Decode Token Stream
  def decode_tokens(tail, tokens) when tail == "" or tail == nil do
    tokens
  end

  def decode_tokens(<<tail::binary>>, tokens) do
    {tokens, tail} = decode_token(tail, tokens)
    decode_tokens(tail, tokens)
  end

  def retval_typ_size(38) do
    # 0x26 - SYBINTN - 1
    8
  end

  def retval_typ_size(dec) do
    # Undefined
    raise Tds.Error,
          "Unknown datatype parsed when decoding return value: #{dec}"
  end

  defp decode_value(<<0x26, size::size(8), size::size(8), data::binary>>) do
    <<value::little-size(size)-unit(8), data::binary>> = data
    {value, data}
  end

  defp decode_token(<<@tds_token_returnvalue, data::binary>>, tokens) do
    <<
      _ord::little-unsigned-16,
      length::size(8),
      name::binary-size(length)-unit(16),
      _status::size(8),
      _usertype::size(32),
      _flags::size(16),
      data::binary
    >> = data

    name = ucs2_to_utf(name)
    {value, data} = decode_value(data)

    {[parameters: {name, value}] ++ tokens, data}
  end

  defp decode_token(
         <<@tds_token_returnstatus, _value::little-size(32), data::binary>>,
         tokens
       ) do
    # todo: add retrun status into tokens
    {tokens, data}
  end

  # COLMETADATA
  defp decode_token(
         <<@tds_token_colmetadata, column_count::little-(2 * 8), tail::binary>>,
         tokens
       ) do
    columns = []
    {columns, tail} = decode_columns(tail, columns, column_count)
    {[columns: columns] ++ tokens, tail}
  end

  # ORDER
  defp decode_token(
         <<@tds_token_order, length::little-unsigned-16, tail::binary>>,
         tokens
       ) do
    length = trunc(length / 2)
    {columns, tail} = decode_column_order(tail, length, [])
    {[order: columns] ++ tokens, tail}
  end

  # ERROR
  defp decode_token(
         <<
           @tds_token_error,
           length::little-size(16),
           number::little-size(32),
           state,
           class,
           msg_len::little-size(16),
           msg::binary-size(msg_len)-unit(16),
           sn_len,
           server_name::binary-size(sn_len)-unit(16),
           pn_len,
           proc_name::binary-size(pn_len)-unit(16),
           line_number::little-size(32),
           _data::binary
         >>,
         _tokens
       ) do
    e = %{
      length: length,
      number: number,
      state: state,
      class: class,
      msg_text: ucs2_to_utf(msg),
      server_name: ucs2_to_utf(server_name),
      proc_name: ucs2_to_utf(proc_name),
      line_number: line_number
    }

    # TODO Need to concat errors for delivery
    # Logger.debug "SQL Error: #{inspect e}"
    {[error: e], nil}
  end

  defp decode_token(
         <<
           @tds_token_info,
           length::little-size(16),
           number::little-size(32),
           state,
           class,
           msg_len::little-size(16),
           msg::binary-size(msg_len)-unit(16),
           sn_len,
           server_name::binary-size(sn_len)-unit(16),
           pn_len,
           proc_name::binary-size(pn_len)-unit(16),
           line_number::little-size(32),
           tail::binary
         >>,
         tokens
       ) do
    i = %{
      length: length,
      number: number,
      state: state,
      class: class,
      msg_text: ucs2_to_utf(msg),
      server_name: ucs2_to_utf(server_name),
      proc_name: ucs2_to_utf(proc_name),
      line_number: line_number
    }

    tokens = Keyword.update(tokens, :info, [i], & [i|&1])
    {tokens, tail}
  end

  ## ROW
  defp decode_token(<<@tds_token_row, tail::binary>>, tokens) do
    column_count = Enum.count(tokens[:columns])
    {row, tail} = decode_row_columns(tail, tokens, [], column_count, 0)
    row = row |> Enum.reverse()

    tokens =
      Keyword.update(tokens, :rows, [row], fn _x -> [row | tokens[:rows]] end)

    {tokens, tail}
  end

  ## NBC ROW
  defp decode_token(<<@tds_token_nbcrow, tail::binary>>, tokens) do
    column_count = Enum.count(tokens[:columns])

    {bitmap_bytes, _} =
      column_count
      |> Kernel./(8)
      |> Float.ceil()
      |> :erlang.float_to_list(decimals: 0)
      |> to_string
      |> Integer.parse()

    {bitmap, tail} = bitmap_list([], tail, bitmap_bytes)
    bitmap = bitmap |> Enum.reverse()
    {row, tail} = decode_row_columns(tail, tokens, [], column_count, 0, bitmap)
    row = row |> Enum.reverse()

    tokens =
      Keyword.update(tokens, :rows, [row], fn _x -> [row | tokens[:rows]] end)

    {tokens, tail}
  end

  defp decode_token(
         <<
           @tds_token_envchange,
           _length::little-unsigned-16,
           env_type::unsigned-8,
           tail::binary
         >>,
         tokens
       ) do
    case env_type do
      # 0x01
      @tds_envtype_database ->
        <<
          new_value_size::unsigned-8,
          new_value::binary-little-size(new_value_size)-unit(8),
          old_value_size::unsigned-8,
          old_value::binary-little-size(old_value_size)-unit(8),
          rest::binary
        >> = tail

        Logger.debug(fn ->
          "Switching from #{new_value} database to #{old_value}"
        end)

        {tokens |> Keyword.put(:database, new_value), rest}

      # 0x02
      # @tds_envtype_language ->

      # 0x03
      # @tds_envtype_characterset ->

      # 0x04
      @tds_envtype_packetsize ->
        <<
          new_value_size::unsigned-8,
          new_value::binary(new_value_size, 16),
          old_value_size::unsigned-8,
          old_value::binary(old_value_size, 16),
          rest::binary
        >> = tail
        new_value = ucs2_to_utf(new_value)
        old_value = ucs2_to_utf(old_value)
        if(new_value != old_value) do
          Logger.debug(fn ->
            """
            Database server configured TDS packetsize to #{new_value} where old value
            was #{old_value}
            """
          end)
        end

        {tokens |> Keyword.put(:packetsize, new_value), rest}

      # 0x05
      # @tds_envtype_unicode_data_storing_local_id ->

      # 0x06
      # @tds_envtype_uncode_data_string_comparison_flag ->

      # 0x07
      # @tds_envtype_sql_collation ->

      # 0x08
      @tds_envtype_begintrans ->
        <<
          value_size::unsigned-8,
          new_value::binary-little-size(value_size)-unit(8),
          0x00,
          rest::binary
        >> = tail

        {tokens |> Keyword.put(:trans, new_value), rest}

      # 0x09
      @tds_envtype_committrans ->
        <<
          0x00,
          value_size::unsigned-8,
          _old_value::binary-little-size(value_size)-unit(8),
          rest::binary
        >> = tail

        {tokens |> Keyword.put(:trans, <<0x00>>), rest}

      # 0x0A
      @tds_envtype_rollbacktrans ->
        <<
          0x00,
          value_size::unsigned-8,
          _old_value::binary-little-size(value_size)-unit(8),
          rest::binary
        >> = tail

        {tokens |> Keyword.put(:trans, <<0x00>>), rest}

      # 0x0B
      # @tds_envtype_enlist_dtc_transaction ->

      # 0x0C
      @tds_envtype_defecttrans ->
        <<
          value_size::unsigned-8,
          new_value::binary-little-size(value_size)-unit(8),
          0x00,
          rest::binary
        >> = tail
        Logger.warn("Defect transaction env change received #{inspect(new_value)}")
        {tokens, rest}

      # 0x0D
      @tds_envtype_mirroring_partner ->
        <<
          0x00,
          new_value_size::unsigned-8,
          _new_value::binary(new_value_size, 16),
          rest::binary
        >> = tail

        {tokens, rest}

      @tds_envtype_routing ->
        <<
          _routing_data_len::little-uint16,
          0x00, #Protocol MUST be 0, specifying TCP-IP protocol
          port::little-uint16,
          alt_host_len::little-uint16,
          alt_host::binary(alt_host_len, 16),
          0x00,
          0x00,
          rest::binary
        >> = tail
        token = %{
          hostname: ucs2_to_utf(alt_host),
          port: port
        }
        {tokens |> Keyword.put(:env_redirect, token), rest}
    end
  end

  ## DONE
  defp decode_token(
         <<
           @tds_token_done,
           status::int16,
           cur_cmd::binary(2),
           row_count::little-size(8)-unit(8),
           tail::binary
         >>,
         tokens
       ) do
    # :binpp.pprint(tail)
    # print_status(status)
    case Keyword.get(tokens, :done) do
      nil ->
        {
          Keyword.put(tokens, :done, %{
            status: status,
            cmd: cur_cmd,
            rows: row_count
          }),
          nil
        }

      %{rows: rows} when row_count > rows ->
        {
          Keyword.put(tokens, :done, %{
            status: status,
            cmd: cur_cmd,
            rows: row_count
          }),
          nil
        }

      _ ->
        {tokens, nil}
    end
  end

  ## DONEPROC
  defp decode_token(
         <<
           @tds_token_doneproc,
           status::int16,
           cur_cmd::binary(2),
           row_count::little-size(8)-unit(8),
           _tail::binary
         >>,
         tokens
       ) do
    case Keyword.get(tokens, :done) do
      nil ->
        {
          Keyword.put(tokens, :done, %{
            status: status,
            cmd: cur_cmd,
            rows: row_count
          }),
          nil
        }

      %{rows: rows} when row_count > rows ->
        {
          Keyword.put(tokens, :done, %{
            status: status,
            cmd: cur_cmd,
            rows: row_count
          }),
          nil
        }

      _ ->
        {tokens, nil}
    end
  end

  ## DONEINPROC
  defp decode_token(
         <<
           @tds_token_doneinproc,
           status::int16,
           cur_cmd::little-size(8)-unit(2),
           row_count::little-size(8)-unit(8),
          #  _something::binary-size(5),
           tail::binary
         >>,
         tokens
       ) do
    case Keyword.get(tokens, :done) do
      nil ->
        {
          Keyword.put(tokens, :done, %{
            status: status,
            cmd: cur_cmd,
            rows: row_count
          }),
          tail
        }

      %{rows: rows} when row_count > rows ->
        {
          Keyword.put(tokens, :done, %{
            status: status,
            cmd: cur_cmd,
            rows: row_count
          }),
          nil
        }

      _ ->
        {tokens, nil}
    end

    # case tokens do
    #   [done: done] ->
    #     cond do
    #       row_count > done.rows -> {[done: %{status: status, cmd: cur_cmd,
    #                   rows: row_count}] ++ tokens, nil}
    #       true -> {tokens, tail}
    #     end
    #     {tokens, nil}
    #   _ ->  {[done: %{status: status, cmd: cur_cmd, rows: row_count}] ++
    #             tokens, tail}
    # end
  end

  defp decode_token(
        <<
          @tds_token_loginack,
          _length::little-uint16,
          interface :: size(8),
          tds_version::binary(4),
          prog_name_len::size(8),
          prog_name::binary(prog_name_len, 16),
          major_ver::size(8),
          minor_ver::size(8),
          build_hi::size(8),
          build_low::size(8),
          tail::binary
        >>,
        tokens
      ) do
    token = %{
      t_sql_only: interface == 1,
      tds_version: "0x#{Base.encode16(tds_version)}",
      program: "#{ucs2_to_utf(prog_name)}",
      version: "#{major_ver}.#{minor_ver}.#{build_hi}.#{build_low}"
    }
    {Keyword.put(tokens, :login_ack, token), tail}
  end

  defp decode_column_order(<<tail::binary>>, n, columns) when n == 0 do
    {columns, tail}
  end

  defp decode_column_order(
         <<col_id::little-unsigned-16, tail::binary>>,
         n,
         columns
       ) do
    decode_column_order(tail, n - 1, [col_id | columns])
  end

  ## Row and Column Decoders

  defp bitmap_list(bitmap, <<tail::binary>>, n) when n <= 0 do
    {bitmap, tail}
  end

  defp bitmap_list(bitmap, <<byte::binary-size(1)-unit(8), tail::binary>>, n)
       when n > 0 do
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

  defp decode_column(<<_usertype::int32, _flags::int16, tail::binary>>) do
    {info, tail} = Types.decode_info(tail)
    {name, tail} = decode_column_name(tail)

    info =
      info
      |> Map.put(:name, name)

    {info, tail}
  end

  defp decode_column_name(<<
         name_length::int8,
         name::unicode(name_length),
         tail::binary
       >>) do
    name = name |> :unicode.characters_to_binary({:utf16, :little}, :utf8)
    {name, tail}
  end

  defp decode_row_columns(<<tail::binary>>, _tokens, row, column_count, n)
       when n >= column_count do
    {row, tail}
  end

  defp decode_row_columns(<<tail::binary>>, tokens, row, column_count, n) do
    {:ok, column} = Enum.fetch(tokens[:columns], n)
    {value, tail} = decode_row_column(tail, column)
    row = [value | row]
    decode_row_columns(tail, tokens, row, column_count, n + 1)
  end

  defp decode_row_columns(
         <<tail::binary>>,
         _tokens,
         row,
         column_count,
         n,
         _bitmap
       )
       when n >= column_count do
    {row, tail}
  end

  defp decode_row_columns(
         <<tail::binary>>,
         tokens,
         row,
         column_count,
         n,
         bitmap
       ) do
    {value, tail} =
      case Enum.fetch(bitmap, n) do
        {:ok, 0} ->
          {:ok, column} = Enum.fetch(tokens[:columns], n)
          decode_row_column(tail, column)

        {_, _} ->
          {nil, tail}
      end

    row = [value | row]
    decode_row_columns(tail, tokens, row, column_count, n + 1, bitmap)
  end

  defp decode_row_column(<<tail::binary>>, column) do
    Types.decode_data(column, tail)
  end
end
