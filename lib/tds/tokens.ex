defmodule Tds.Tokens do
  @moduledoc false

  import Tds.Protocol.Binary
  import Tds.Protocol.Constants
  import Bitwise

  require Logger

  alias Tds.Encoding.UCS2
  alias Tds.Type.{DataReader, Registry}
  alias Tds.Types

  @registry Registry.new()

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
  # | :eof # end of message marker

  ## Decode Token Stream
  @spec decode_tokens(any, any) :: [{token, any}]
  def decode_tokens(binary, colmetadata \\ nil)

  def decode_tokens(tail, _) when tail == "" or tail == nil do
    []
  end

  def decode_tokens(
        <<token::unsigned-size(8), tail::binary>>,
        collmetadata
      ) do
    {token_data, tail, collmetadata} =
      case token do
        token(:colmetadata) ->
          decode_colmetadata(tail, collmetadata)

        token(:done) ->
          decode_done(tail, collmetadata)

        token(:doneproc) ->
          decode_doneproc(tail, collmetadata)

        token(:doneinproc) ->
          decode_doneinproc(tail, collmetadata)

        token(:envchange) ->
          decode_envchange(tail, collmetadata)

        token(:error) ->
          decode_error(tail, collmetadata)

        token(:info) ->
          decode_info(tail, collmetadata)

        token(:loginack) ->
          decode_loginack(tail, collmetadata)

        token(:nbcrow) ->
          decode_nbcrow(tail, collmetadata)

        token(:order) ->
          decode_order(tail, collmetadata)

        token(:returnstatus) ->
          decode_returnstatus(tail, collmetadata)

        token(:returnvalue) ->
          decode_returnvalue(tail, collmetadata)

        token(:row) ->
          decode_row(tail, collmetadata)

        t ->
          raise_unsupported_token(t, collmetadata)
      end

    [token_data | decode_tokens(tail, collmetadata)]
  end

  defp raise_unsupported_token(token, _) do
    raise RuntimeError,
          "Unsupported Token code " <>
            "#{inspect(token, base: :hex)} in Token Stream"
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

    name = UCS2.to_string(name)
    {meta, tail} = decode_type_metadata(data)
    {value, tail} = decode_type_value(meta, tail)
    param = %Tds.Parameter{name: name, value: value, direction: :output}
    {{:returnvalue, param}, tail, collmetadata}
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
  defp decode_order(
         <<length::little-unsigned-16, tail::binary>>,
         collmetadata
       ) do
    length = trunc(length / 2)
    {columns, tail} = decode_column_order(tail, length)
    {{:order, columns}, tail, collmetadata}
  end

  # ERROR
  defp decode_error(
         <<l::little-size(16), data::binary-size(l),
           tail::binary>>,
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
      msg_text: UCS2.to_string(:binary.copy(msg)),
      server_name: UCS2.to_string(:binary.copy(server_name)),
      proc_name: UCS2.to_string(:binary.copy(proc_name)),
      line_number: line_number
    }

    {{:error, e}, tail, collmetadata}
  end

  defp decode_info(
         <<l::little-size(16), data::binary-size(l),
           tail::binary>>,
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
      msg_text: UCS2.to_string(msg),
      server_name: UCS2.to_string(server_name),
      proc_name: UCS2.to_string(proc_name),
      line_number: line_number
    }

    Logger.debug(fn ->
      [
        "(Tds.Info)",
        "Line",
        to_string(info.line_number),
        "(Class #{info.class})",
        info.msg_text
      ]
      |> Enum.intersperse(" ")
      |> IO.iodata_to_binary()
    end)

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
    bitmap_bytes = round(Float.ceil(column_count / 8))
    {bitmap, tail} = bitmap_list(tail, bitmap_bytes)
    {row, tail} = decode_nbcrow_columns(tail, collmetadata, bitmap)

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
            old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          new_database = UCS2.to_string(new_value)
          old_database = UCS2.to_string(old_value)
          {{:database, new_database, old_database}, rest}

        0x02 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          new_language = UCS2.to_string(new_value)
          old_language = UCS2.to_string(old_value)
          {{:language, new_language, old_language}, rest}

        0x03 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          new_charset = UCS2.to_string(new_value)
          old_charset = UCS2.to_string(old_value)
          {{:charset, new_charset, old_charset}, rest}

        0x04 ->
          <<
            new_value_size::unsigned-8,
            new_value::binary(new_value_size, 16),
            old_value_size::unsigned-8,
            old_value::binary(old_value_size, 16),
            rest::binary
          >> = tail

          new_packetsize =
            new_value
            |> UCS2.to_string()
            |> Integer.parse()
            |> case do
              :error -> 4096
              {value, ""} -> value
              {value, _maybe_unit} -> value
            end

          old_packetsize =
            old_value
            |> UCS2.to_string()
            |> Integer.parse()
            |> case do
              :error -> 4096
              {value, ""} -> value
              {value, _maybe_unit} -> value
            end

          {{:packetsize, new_packetsize, old_packetsize}, rest}

        0x07 ->
          <<
            new_value_size::unsigned-8,
            collation::binary(new_value_size, 8),
            old_value_size::unsigned-8,
            _old_value::binary(old_value_size, 8),
            rest::binary
          >> = tail

          {:ok, collation} = Tds.Protocol.Collation.decode(collation)
          {{:collation, collation, nil}, rest}

        0x08 ->
          <<
            value_size::unsigned-8,
            new_value::binary-little-size(value_size)-unit(8),
            0x00,
            rest::binary
          >> = tail

          new_trans = :binary.copy(new_value)
          {{:transaction_begin, new_trans, <<0x00>>}, rest}

        0x09 ->
          <<
            0x00,
            value_size::unsigned-8,
            old_value::binary-little-size(value_size)-unit(8),
            rest::binary
          >> = tail

          old_trans = :binary.copy(old_value)
          {{:transaction_commit, <<0x00>>, old_trans}, rest}

        0x0A ->
          <<
            0x00,
            value_size::unsigned-8,
            old_value::binary-little-size(value_size)-unit(8),
            rest::binary
          >> = tail

          trans = :binary.copy(old_value)
          {{:transaction_rollback, <<0x00>>, trans}, rest}

        0x0C ->
          <<
            value_size::unsigned-8,
            new_value::binary-little-size(value_size)-unit(8),
            0x00,
            rest::binary
          >> = tail

          tran = :binary.copy(new_value)
          {{:transaction_defect, tran, <<0x00>>}, rest}

        0x0D ->
          <<
            new_value_size::unsigned-8,
            _new_value::binary(new_value_size, 16),
            0x00,
            rest::binary
          >> = tail

          {{:mirroring_partner, :ignore_me, :ignore_me}, rest}

        0x11 ->
          <<
            0x00,
            value_size::unsigned-8,
            old_value::binary-little-size(value_size)-unit(8),
            rest::binary
          >> = tail

          old = :binary.copy(old_value)
          {{:transaction_ended, <<0x00>>, old}, rest}

        0x12 ->
          <<0x00, 0x00, rest::binary>> = tail
          {{:resetconnection_ack, 0x00, 0x00}, rest}

        0x13 ->
          <<
            size::uint16(),
            value::binary(size, 16),
            0x00,
            rest::binary
          >> = tail

          {{:userinfo, UCS2.to_string(value), nil}, rest}

        0x14 ->
          <<
            _routing_data_len::uint16(),
            0x00,
            port::uint16(),
            alt_host_len::uint16(),
            alt_host::binary(alt_host_len, 16),
            0x00,
            0x00,
            rest::binary
          >> = tail

          {hostname, instance} =
            UCS2.to_string(alt_host)
            |> String.split("\\")
            |> case do
              [host, inst] -> {host, inst}
              [host] -> {host, nil}
            end

          routing = %{
            hostname: hostname,
            instance: instance,
            port: port
          }

          {{:routing, routing, nil}, rest}
      end

    {{:envchange, token}, tail, colmetadata}
  end

  ## DONE
  defp decode_done(
         <<
           status::little-unsigned-size(2)-unit(8),
           cur_cmd::little-unsigned-size(2)-unit(8),
           row_count::little-size(8)-unit(8),
           tail::binary
         >>,
         collmetadata
       ) do
    status = %{
      final?: band(status, 0x0001) == 0x0,
      more?: band(status, 0x0001) == 0x1,
      error?: band(status, 0x0002) == 0x2,
      inxact?: band(status, 0x0004) == 0x4,
      count?: band(status, 0x0010) == 0x10,
      atnn?: band(status, 0x0020) == 0x20,
      rpc_in_batch?: band(status, 0x0080) == 0x80,
      srverror?: band(status, 0x0100) == 0x100
    }

    done = %{
      status: status,
      cmd: cur_cmd,
      rows: row_count
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
           _length::uint16(),
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
      program: UCS2.to_string(prog_name),
      version:
        "#{major_ver}.#{minor_ver}.#{build_hi}.#{build_low}"
    }

    {{:loginack, token}, tail, collmetadata}
  end

  defp decode_column_order(tail, n, acc \\ [])

  defp decode_column_order(tail, n, acc) when n < 1 do
    {Enum.reverse(acc), tail}
  end

  defp decode_column_order(
         <<col_id::little-unsigned-16, tail::binary>>,
         n,
         acc
       ) do
    decode_column_order(tail, n - 1, [col_id | acc])
  end

  ## Row and Column Decoders

  defp bitmap_list(tail, n) when n <= 0 do
    {[], tail}
  end

  defp bitmap_list(
         <<b8::1, b7::1, b6::1, b5::1, b4::1, b3::1, b2::1,
           b1::1, tail::binary>>,
         n
       ) do
    {bits, tail} = bitmap_list(tail, n - 1)
    {[b1, b2, b3, b4, b5, b6, b7, b8 | bits], tail}
  end

  defp decode_columns(data, n, acc \\ [])

  defp decode_columns(tail, n, acc) when n < 1 do
    {Enum.reverse(acc), tail}
  end

  defp decode_columns(data, n, acc) do
    {column, tail} = decode_column(data)
    decode_columns(tail, n - 1, [column | acc])
  end

  defp decode_column(
         <<_usertype::int32(), _flags::int16(), tail::binary>>
       ) do
    {info, tail} = decode_type_metadata(tail)
    {name, tail} = decode_column_name(tail)

    info = Map.put(info, :name, name)
    {info, tail}
  end

  defp decode_column_name(
         <<length::int8(), name::binary-size(length)-unit(16),
           tail::binary>>
       ) do
    name = UCS2.to_string(name)
    {name, tail}
  end

  defp decode_row_columns(binary, colmetadata, acc \\ [])

  defp decode_row_columns(<<tail::binary>>, [], acc) do
    {Enum.reverse(acc), tail}
  end

  defp decode_row_columns(
         <<data::binary>>,
         [column_meta | colmetadata],
         acc
       ) do
    {column, tail} = decode_type_value(column_meta, data)
    decode_row_columns(tail, colmetadata, [column | acc])
  end

  defp decode_nbcrow_columns(
         binary,
         colmetadata,
         bitmap,
         acc \\ []
       )

  defp decode_nbcrow_columns(<<tail::binary>>, [], _bitmap, acc) do
    {Enum.reverse(acc), tail}
  end

  defp decode_nbcrow_columns(
         <<tail::binary>>,
         colmetadata,
         bitmap,
         acc
       ) do
    [column_meta | colmetadata] = colmetadata
    [bit | bitmap] = bitmap

    {column, tail} =
      case bit do
        0 -> decode_type_value(column_meta, tail)
        _ -> {nil, tail}
      end

    decode_nbcrow_columns(
      tail,
      colmetadata,
      bitmap,
      [column | acc]
    )
  end

  # -- New type system pipeline ----------------------------------------

  # Decodes type metadata from binary using Registry + handler.
  # Returns {metadata_with_handler, rest}.
  defp decode_type_metadata(
         <<type_code::unsigned-8, _::binary>> = bin
       ) do
    case Registry.handler_for_code(@registry, type_code) do
      {:ok, handler} ->
        {:ok, meta, rest} = handler.decode_metadata(bin)
        {Map.put(meta, :handler, handler), rest}

      :error ->
        {info, rest} = Types.decode_info(bin)
        {info, rest}
    end
  end

  # Decodes a column value using DataReader + handler.decode.
  # Falls back to Types.decode_data for unrecognized metadata.
  defp decode_type_value(%{handler: handler} = meta, bin) do
    {raw, rest} = DataReader.read(meta.data_reader, bin)
    value = handler.decode(raw, meta)
    {value, rest}
  end

  defp decode_type_value(meta, bin) do
    Types.decode_data(meta, bin)
  end
end
