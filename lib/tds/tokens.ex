defmodule Tds.Tokens do
  import Tds.BinaryUtils
  import Tds.Utils
  import Bitwise

  require Logger

  alias Tds.Types

  def retval_typ_size(38) do
    # 0x26 - SYBINTN - 1
    8
  end

  def retval_typ_size(dec) do
    # Undefined
    raise Tds.Error,
          "Unknown datatype parsed when decoding return value: #{dec}"
  end

  @type token ::
          :colmetadata
          | :done
          | :doneinproc
          | :doneproc
          | :envchange
          | :error
          | :info
          | :loginack
          | :order
          | :parameters
          | :returnstatus
          | :row

  ## Decode Token Stream
  @spec decode_tokens(any, any) :: [{token, any}]
  def decode_tokens(binary, colmetadata \\ nil)

  def decode_tokens(tail, _) when tail == "" or tail == nil do
    []
  end

  def decode_tokens(<<token::unsigned-size(8), tail::binary>>, collmetadata) do
    {token_data, tail, collmetadata} =
      case token do
        0x81 -> decode_colmetadata(tail, collmetadata)
        # 0xA5 -> decode_colinfo(tail, collmetadata)
        0xFD -> decode_done(tail, collmetadata)
        0xFE -> decode_doneproc(tail, collmetadata)
        0xFF -> decode_doneinproc(tail, collmetadata)
        0xE3 -> decode_envchange(tail, collmetadata)
        0xAA -> decode_error(tail, collmetadata)
        # 0xAE -> decode_featureextack(tail, collmetadata)
        # 0xEE -> decode_fedauthinfo(tail, collmetadata)
        0xAB -> decode_info(tail, collmetadata)
        0xAD -> decode_loginack(tail, collmetadata)
        0xD2 -> decode_nbcrow(tail, collmetadata)
        # 0x78 -> decode_offset(tail, collmetadata)
        0xA9 -> decode_order(tail, collmetadata)
        0x79 -> decode_returnstatus(tail, collmetadata)
        0xAC -> decode_returnvalue(tail, collmetadata)
        0xD1 -> decode_row(tail, collmetadata)
        # 0xE4 -> decode_sessionstate(tail, collmetadata)
        # 0xED -> decode_sspi(tail, collmetadata)
        # 0xA4 -> decode_tablename(tail, collmetadata)
        t -> raise_unsupported_token(t, collmetadata)
      end

    [token_data | decode_tokens(tail, collmetadata)]
  end

  defp raise_unsupported_token(token, _) do
    raise RuntimeError,
          "Unsupported Token code #{inspect(token, base: :hex)} in Token Stream"
  end

  defp decode_returnvalue(bin, collmetadata) do
    <<
      _ord::little-unsigned-16,
      length::size(8),
      name::binary-size(length)-unit(16),
      _status::size(8),
      _usertype::size(32),
      _flags::size(16),
      data::binary
    >> = bin

    name = ucs2_to_utf(name)

    {value, data} =
      case data do
        <<0x26, size::size(8), size::size(8), data::binary>> ->
          <<value::little-size(size)-unit(8), data::binary>> = data
          {value, data}
          # todo: support other return types
      end

    {{:parameters, {name, value}}, data, collmetadata}
  end

  defp decode_returnstatus(
         <<value::little-size(32), tail::binary>>,
         collmetadata
       ) do
    {{:returnstatus, value}, tail, collmetadata}
  end

  # COLMETADATA
  defp decode_colmetadata(
         <<column_count::little-size(2)-unit(8), tail::binary>>,
         _
       ) do
    {colmetadata, tail} = decode_columns(tail, column_count)
    {{:colmetadata, colmetadata}, tail, colmetadata}
  end

  # ORDER
  defp decode_order(<<length::little-unsigned-16, tail::binary>>, collmetadata) do
    length = trunc(length / 2)
    {columns, tail} = decode_column_order(tail, length)
    {{:order, columns}, tail, collmetadata}
  end

  # ERROR
  defp decode_error(
         <<l::little-size(16), data::binary-size(l), tail::binary>>,
         collmetadata
       ) do
    <<
      number::little-size(32),
      state,
      class,
      msg_len::little-size(16),
      msg::binary-size(msg_len)-unit(16),
      sn_len,
      server_name::binary-size(sn_len)-unit(16),
      pn_len,
      proc_name::binary-size(pn_len)-unit(16),
      line_number::little-size(32)
    >> = data

    e = %{
      number: number,
      state: state,
      class: class,
      msg_text: ucs2_to_utf(:binary.copy(msg)),
      server_name: ucs2_to_utf(:binary.copy(server_name)),
      proc_name: ucs2_to_utf(:binary.copy(proc_name)),
      line_number: line_number
    }

    # TODO Need to concat errors for delivery
    # Logger.debug "SQL Error: #{inspect e}"
    {{:error, e}, tail, collmetadata}
  end

  defp decode_info(
         <<l::little-size(16), data::binary-size(l), tail::binary>>,
         collmetadata
       ) do
    <<
      number::little-size(32),
      state,
      class,
      msg_len::little-size(16),
      msg::binary-size(msg_len)-unit(16),
      sn_len,
      server_name::binary-size(sn_len)-unit(16),
      pn_len,
      proc_name::binary-size(pn_len)-unit(16),
      line_number::little-size(32)
    >> = data

    info = %{
      number: number,
      state: state,
      class: class,
      msg_text: ucs2_to_utf(msg),
      server_name: ucs2_to_utf(server_name),
      proc_name: ucs2_to_utf(proc_name),
      line_number: line_number
    }

    Logger.info(info.msg_text)
    # tokens = Keyword.update(tokens, :info, [i], &[i | &1])
    {{:info, info}, tail, collmetadata}
  end

  ## ROW
  defp decode_row(<<tail::binary>>, collmetadata) do
    {row, tail} = decode_row_columns(tail, collmetadata)
    {{:row, row}, tail, collmetadata}
  end

  ## NBC ROW
  defp decode_nbcrow(<<tail::binary>>, collmetadata) do
    column_count = Enum.count(collmetadata)
    bitmap_bytes = round(8 * Float.ceil(column_count / 8))
    {bitmap, tail} = bitmap_list(tail, bitmap_bytes)
    bitmap = bitmap |> Enum.reverse()
    {row, tail} = decode_row_columns(tail, collmetadata, bitmap)

    {{:row, row}, tail, collmetadata}
  end

  defp decode_envchange(
         <<
           _length::little-unsigned-16,
           env_type::unsigned-8,
           tail::binary
         >>,
         colmetadata
       ) do
    {token, tail} =
      case env_type do
        0x01 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            _old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          database = ucs2_to_utf(new_value)
          {{:database, database}, rest}

        0x02 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            _old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          language = ucs2_to_utf(new_value)
          {{:language, language}, rest}

        0x03 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            _old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          charset = ucs2_to_utf(new_value)
          {{:charset, charset}, rest}

        0x04 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            _old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          packetsize =
            new_value
            |> ucs2_to_utf()
            |> Integer.parse()
            |> case do
              :error -> 4096
              {value, ""} -> value
              {value, _maybe_unit} -> value
            end

          {{:packetsize, packetsize}, rest}

        # 0x05
        # @tds_envtype_unicode_data_storing_local_id ->

        # 0x06
        # @tds_envtype_uncode_data_string_comparison_flag ->

        0x07 ->
          <<
            new_value_size::unsigned-8,
            collation::binary(new_value_size, 8),
            old_value_size::unsigned-8,
            _::binary(old_value_size, 8),
            rest::binary
          >> = tail

          {:ok, collation} = Tds.Protocol.Collation.decode(collation)
          {{:collation, collation}, rest}

        0x08 ->
          <<
            value_size::unsigned-8,
            new_value::binary-little-size(value_size)-unit(8),
            0x00,
            rest::binary
          >> = tail

          {{:transaction_begin, new_value}, rest}

        0x09 ->
          <<
            0x00,
            value_size::unsigned-8,
            _old_value::binary-little-size(value_size)-unit(8),
            rest::binary
          >> = tail

          {{:transaction_commit, <<0x00>>}, rest}

        0x0A ->
          <<
            0x00,
            value_size::unsigned-8,
            _old_value::binary-little-size(value_size)-unit(8),
            rest::binary
          >> = tail

          {{:transaction_rollback, <<0x00>>}, rest}

        # 0x0B
        # @tds_envtype_enlist_dtc_transaction ->

        0x0C ->
          <<
            value_size::unsigned-8,
            new_value::binary-little-size(value_size)-unit(8),
            0x00,
            rest::binary
          >> = tail

          Logger.warn(fn ->
            "Defect transaction env change received #{inspect(new_value)}"
          end)

          {{:transaction_defect, new_value}, rest}

        0x0D ->
          <<
            0x00,
            new_value_size::unsigned-8,
            _new_value::binary(new_value_size, 16),
            rest::binary
          >> = tail

          {{:mirroring_partner, :ignore_me}, rest}

        0x11 ->
          <<
            0x00,
            value_size::unsigned-8,
            _old_value::binary-little-size(value_size)-unit(8),
            rest::binary
          >> = tail

          {{:transaction_ended, <<0x00>>}, rest}

        0x12 ->
          <<0x00, 0x00, rest::binary>> = tail
          {{:resetconnection_ack, 0x00}, rest}

        0x13 ->
          <<
            size::little-uint16,
            value::binary(size, 16),
            0x00,
            rest::binary
          >> = tail

          {{:user_info, ucs2_to_utf(value)}, rest}

        0x14 ->
          <<
            _routing_data_len::little-uint16,
            # Protocol MUST be 0, specifying TCP-IP protocol
            0x00,
            port::little-uint16,
            alt_host_len::little-uint16,
            alt_host::binary(alt_host_len, 16),
            0x00,
            0x00,
            rest::binary
          >> = tail

          routing = %{
            hostname: ucs2_to_utf(alt_host),
            port: port
          }

          {{:routing, routing}, rest}
      end

    {{:envchange, token}, tail, colmetadata}
  end

  ## DONE
  defp decode_done(
         <<status::int16, cur_cmd::binary(2), row_count::little-size(8)-unit(8),
           tail::binary>>,
         collmetadata
       ) do
    status = %{
      final?: band(status, 0x00) == 0x00,
      more?: band(status, 0x01) == 0x01,
      error?: band(status, 0x02) == 0x02,
      inxact?: band(status, 0x04) == 0x04,
      count?: band(status, 0x10) == 0x10,
      atnn?: band(status, 0x20) == 0x20,
      rpc_in_batch?: band(status, 0x80) == 0x80,
      srverror?: band(status, 0x100) == 0x100
    }

    done = %{
      status: status,
      cmd: cur_cmd,
      rows: if(status.count?, do: row_count)
    }

    {{:done, done}, tail, collmetadata}
  end

  ## DONEPROC
  defp decode_doneproc(<<tail::binary>>, collmetadata) do
    {{_, done}, tail, _} = decode_done(tail, collmetadata)
    {{:doneproc, done}, tail, collmetadata}
  end

  ## DONEINPROC
  defp decode_doneinproc(<<tail::binary>>, collmetadata) do
    {{_, done}, tail, _} = decode_done(tail, collmetadata)
    {{:doneinproc, done}, tail, collmetadata}
  end

  defp decode_loginack(
         <<
           _length::little-uint16,
           interface::size(8),
           tds_version::unsigned-32,
           prog_name_len::size(8),
           prog_name::binary(prog_name_len, 16),
           major_ver::size(8),
           minor_ver::size(8),
           build_hi::size(8),
           build_low::size(8),
           tail::binary
         >>,
         collmetadata
       ) do
    token = %{
      t_sql_only: interface == 1,
      tds_version: tds_version,
      program: ucs2_to_utf(prog_name),
      version: "#{major_ver}.#{minor_ver}.#{build_hi}.#{build_low}"
    }

    {{:loginack, token}, tail, collmetadata}
  end

  defp decode_column_order(tail, n) when n < 1 do
    {[], tail}
  end

  defp decode_column_order(<<col_id::little-unsigned-16, tail::binary>>, n) do
    {col_ids, tail} = decode_column_order(tail, n - 1)
    {[col_id | col_ids], tail}
  end

  ## Row and Column Decoders

  defp bitmap_list(tail, n) when n <= 0 do
    {[], tail}
  end

  defp bitmap_list(<<byte::binary-8, tail::binary>>, n) do
    <<b8::1, b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1>> = byte
    {bits, tail} = bitmap_list(tail, n - 1)
    {[b1, b2, b3, b4, b5, b6, b7, b8 | bits], tail}
  end

  defp decode_columns(tail, n) when n < 1 do
    {[], tail}
  end

  defp decode_columns(data, n) do
    Stream.resource(
      fn -> {0, data} end,
      fn {i, tail} ->
        cond do
          i < n ->
            {column, tail} = decode_column(tail)
            {[column], {i + 1, tail}}

          i == n ->
            {[tail], {i + 1, tail}}

          i > n ->
            {:halt, {i}}
        end
      end,
      fn _ -> nil end
    )
    |> Stream.chunk_every(n)
    |> Enum.to_list()
    |> case do
      [columns, [tail]] -> {columns, tail}
      [] -> {[], data}
    end

    # {column, tail} = decode_column(data)
    # {[column | decode_columns(tail, n - 1)], tail}
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
         name::binary-size(name_length)-unit(16),
         tail::binary
       >>) do
    name = ucs2_to_utf(name)
    {name, tail}
  end

  defp decode_row_columns(<<tail::binary>>, []) do
    {[], tail}
  end

  defp decode_row_columns(<<data::binary>>, colmetadata) do
    n = Enum.count(colmetadata)

    Stream.resource(
      fn -> {0, data, colmetadata} end,
      fn {i, tail, metadata} ->
        cond do
          i < n ->
            [hmeta | tmeta] = metadata
            {column, tail} = decode_row_column(tail, hmeta)
            {[column], {i + 1, tail, tmeta}}

          i == n ->
            {[tail], {i + 1, tail, metadata}}

          i > n ->
            {:halt, {i}}
        end
      end,
      fn _ -> nil end
    )
    |> Stream.chunk_every(n)
    |> Enum.to_list()
    |> case do
      [columns, [tail]] -> {columns, tail}
      [] -> {[], data}
    end

    # {column, tail} = decode_row_column(tail, column_meta)
    # {row, tail} = decode_row_columns(tail, colmetadata)
    # {[column | row], tail}
  end

  defp decode_row_columns(<<tail::binary>>, [], _bitmap) do
    {[], tail}
  end

  defp decode_row_columns(<<tail::binary>>, [column_meta | colmetadata], [
         bit | bitmap
       ]) do
    {column, tail} =
      case bit do
        0 -> decode_row_column(tail, column_meta)
        _ -> {nil, tail}
      end

    {row, tail} = decode_row_columns(tail, colmetadata, bitmap)

    {[column | row], tail}
  end

  defp decode_row_column(<<tail::binary>>, column_meta) do
    Types.decode_data(column_meta, tail)
  end
end
