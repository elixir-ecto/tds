defmodule Tds.Messages do
  @moduledoc false

  import Record, only: [defrecord: 2]
  import Tds.Tokens, only: [decode_tokens: 1]

  alias Tds.Encoding.UCS2
  alias Tds.Parameter
  alias Tds.Protocol.{Login7, Prelogin}
  alias Tds.Types

  require Bitwise
  require Logger

  # requests
  defrecord :msg_prelogin, [:params]
  defrecord :msg_login, [:params]
  defrecord :msg_ready, [:status]
  defrecord :msg_sql, [:query]
  defrecord :msg_transmgr, [:command, :name, :isolation_level]
  defrecord :msg_rpc, [:proc, :query, :params]
  defrecord :msg_attn, []

  # responses
  defrecord :msg_preloginack, [:response]
  defrecord :msg_loginack, [:redirect]
  defrecord :msg_prepared, [:params]
  defrecord :msg_sql_result, [:columns, :rows, :row_count]
  defrecord :msg_result, [:set, :params, :status]
  defrecord :msg_trans, [:trans]
  defrecord :msg_error, [:error]

  ## Microsoft Stored Procedures
  # @tds_sp_cursor 1
  # @tds_sp_cursoropen 2
  # @tds_sp_cursorprepare 3
  # @tds_sp_cursorexecute 4
  # @tds_sp_cursorprepexec 5
  # @tds_sp_cursorunprepare 6
  # @tds_sp_cursorfetch 7
  # @tds_sp_cursoroption 8
  # @tds_sp_cursorclose 9
  @tds_sp_executesql 10
  @tds_sp_prepare 11
  @tds_sp_execute 12
  # @tds_sp_prepexec 13
  # @tds_sp_prepexecrpc 14
  @tds_sp_unprepare 15

  ## Packet Size
  @tds_pack_data_size 4088
  # @tds_pack_header_size 8
  # @tds_pack_size @tds_pack_header_size + @tds_pack_data_size

  ## Packet Types
  # @tds_pack_sqlbatch    1
  # @tds_pack_rpcRequest  3
  @tds_pack_cancel 6
  # @tds_pack_bulkloadbcp 7
  # @tds_pack_transmgrreq 14
  # @tds_pack_normal      15
  # @tds_pack_login7      16
  # @tds_pack_sspimessage 17
  # @tds_pack_prelogin    18

  ## Parsers
  def parse(:prelogin, packet_data, s) do
    response = Prelogin.decode(packet_data, s)
    {msg_preloginack(response: response), s}
  end

  def parse(:login, packet_data, s) do
    packet_data
    |> decode_tokens()
    |> Enum.reduce({msg_loginack(), s}, fn
      {:envchange, {:routing, r, _}}, {msg_loginack() = msg, s} ->
        {msg_loginack(msg, redirect: r), s}

      {:envchange, other}, {msg, s} ->
        {msg, on_envchange(other, s)}

      {:loginack, %{tds_version: version}}, {msg, s} ->
        Process.put(:tds_version, version)
        {msg, s}

      {:error, error}, {msg_error(), _s} = msg_s ->
        %Tds.Error{mssql: error}
        |> Tds.Error.message()
        |> Logger.error()

        msg_s

      {:error, error}, _ ->
        {msg_error(error: error), s}

      _, msg ->
        # FeatureExtAck should be processed here in future
        msg
    end)
  end

  def parse(:prepare, packet_data, s) do
    packet_data
    |> decode_tokens()
    |> Enum.reduce({msg_prepared(), s}, fn
      {:envchange, env}, {msg, s} ->
        {msg, on_envchange(env, s)}

      {:error, error}, {msg_error(), _s} = msg_s ->
        Logger.debug(fn ->
          %Tds.Error{mssql: error}
          |> Tds.Error.message()
        end)

        msg_s

      {:error, error}, {_, s} ->
        {msg_error(error: error), s}

      {:returnvalue, param}, {msg_prepared(params: params) = m, s} ->
        m = msg_prepared(m, params: [param | List.wrap(params)])
        {m, s}

      _, msg ->
        msg
    end)
  end

  def parse(:transaction_manager, packet_data, s) do
    packet_data
    |> decode_tokens()
    |> Enum.reduce({msg_trans(), s}, fn
      {:envchange, env}, {msg, s} ->
        {msg, on_envchange(env, s)}

      {:error, error}, {msg_error(), _s} = msg_s ->
        %Tds.Error{mssql: error}
        |> Tds.Error.message()
        |> Logger.error()

        msg_s

      {:error, error}, {_, s} ->
        {msg_error(error: error), s}

      _, msg ->
        msg
    end)
  end

  def parse(:executing, packet_data, s) do
    packet_data
    |> decode_tokens()
    |> Enum.reduce({msg_result(set: [], params: [], status: 0), nil, s}, fn
      {:envchange, env}, {m, c, s} ->
        {m, c, on_envchange(env, s)}

      {:colmetadata, colmetadata}, {msg_result() = m, _, s} ->
        curr = %Tds.Result{
          columns: transform(colmetadata, :name),
          rows: [],
          num_rows: 0
        }

        {m, curr, s}

      {:row, row}, {msg_result() = m, c, s} ->
        c = %{c | rows: [row | c.rows], num_rows: c.num_rows + 1}
        {m, c, s}

      {token, %{status: status, rows: num_rows}}, {msg_result(set: set) = m, c, s}
      when token in [:done, :doneinproc, :doneproc] ->
        cond do
          status.count? and is_nil(c) ->
            c = %Tds.Result{num_rows: num_rows}
            {msg_result(m, set: [c | set]), nil, s}

          not is_nil(c) ->
            {msg_result(m, set: [c | set]), nil, s}

          :else ->
            {m, nil, s}
        end

      {:parameters, param}, {msg_result(params: params) = m, c, s} ->
        m = msg_result(m, params: [param | params])
        {m, c, s}

      {:returnstatus, status}, {msg_result() = m, c, s} ->
        m = msg_result(m, status: status)
        {m, c, s}

      {:error, error}, {_, _, s} ->
        {msg_error(error: error), nil, s}

      _, any ->
        any
    end)
    |> case do
      {msg_result(set: set) = msg, _, s} ->
        set = Enum.reverse(set)
        {msg_result(msg, set: set), s}

      {msg_error() = msg, _, s} ->
        {msg, s}
    end
  end

  defp on_envchange(envchnage, %{env: env} = s) do
    case envchnage do
      {:packetsize, new_value, _} ->
        %{s | env: Map.put(env, :packetsize, new_value)}

      {:collation, new_value, _} ->
        %{s | env: Map.put(env, :collation, new_value)}

      {:transaction_begin, new_value, _} ->
        %{s | env: %{env | trans: new_value}}

      {:transaction_commit, new_value, _} ->
        %{s | env: %{env | trans: new_value, savepoint: 0}, transaction: nil}

      {:transaction_rollback, new_value, _} ->
        %{s | env: %{env | trans: new_value, savepoint: 0}, transaction: nil}

      _ ->
        s
    end
  end

  defp transform(list, key, acc \\ [])
  defp transform([], _key, acc), do: acc |> Enum.reverse()

  defp transform([h | t], key, acc) when is_map(h),
    do: transform(t, key, [Map.get(h, key) | acc])

  defp transform([h | t], key, acc) when is_list(h),
    do: transform(t, key, [Keyword.get(h, key) | acc])

  ## Encoders

  def encode_msg(msg, env) do
    encode(msg, env)
  end

  defp encode(msg_prelogin(params: opts), _env) do
    Prelogin.encode(opts)
  end

  defp encode(msg_login(params: opts), _env) do
    opts
    |> Login7.new()
    |> Login7.encode()
  end

  defp encode(msg_attn(), _s) do
    encode_packets(@tds_pack_cancel, <<>>)
  end

  defp encode(msg_sql(query: q), %{trans: trans}) do
    # convert query to unicodestream
    q_ucs = UCS2.from_string(q)

    # Transaction Descriptor header
    header_type = <<2::little-size(2)-unit(8)>>
    trans_size = byte_size(trans)
    padding = 8 - trans_size
    transaction_descriptor = trans <> <<0::size(padding)-unit(8)>>
    outstanding_request_count = <<1::little-size(4)-unit(8)>>

    td_header = header_type <> transaction_descriptor <> outstanding_request_count

    td_header_len = byte_size(td_header) + 4
    td_header = <<td_header_len::little-size(4)-unit(8)>> <> td_header

    headers = td_header
    total_length = byte_size(headers) + 4
    all_headers = <<total_length::little-size(32)>> <> headers
    data = all_headers <> q_ucs
    encode_packets(0x01, data)
  end

  defp encode(msg_rpc(proc: proc, params: params), %{trans: trans}) do
    # Transaction Descriptor header
    header_type = <<2::little-size(2)-unit(8)>>
    trans_size = byte_size(trans)
    padding = 8 - trans_size
    transaction_descriptor = trans <> <<0::size(padding)-unit(8)>>
    outstanding_request_count = <<1::little-size(4)-unit(8)>>

    td_header = header_type <> transaction_descriptor <> outstanding_request_count

    td_header_len = byte_size(td_header) + 4
    td_header = <<td_header_len::little-size(4)-unit(8)>> <> td_header

    headers = td_header
    total_length = byte_size(headers) + 4
    all_headers = <<total_length::little-size(32)>> <> headers

    data = all_headers <> encode_rpc(proc, params)
    # layout Data
    encode_packets(0x03, data)
  end

  defp encode(msg_transmgr(command: "TM_BEGIN_XACT", isolation_level: isolation_level), %{
         trans: trans
       }) do
    isolation = encode_isolation_level(isolation_level)
    encode_trans(5, trans, <<isolation::size(1)-unit(8), 0x0::size(1)-unit(8)>>)
  end

  defp encode(msg_transmgr(command: "TM_COMMIT_XACT"), %{trans: trans}) do
    encode_trans(7, trans, <<0, 0>>)
  end

  defp encode(msg_transmgr(command: "TM_ROLLBACK_XACT", name: name), %{trans: trans}) do
    payload =
      if name > 0,
        do: <<2::unsigned-8, name::little-size(2)-unit(8), 0x0::size(1)-unit(8)>>,
        else: <<0x00::size(2)-unit(8)>>

    encode_trans(8, trans, payload)
  end

  defp encode(msg_transmgr(command: "TM_SAVE_XACT", name: savepoint), %{trans: trans}) do
    encode_trans(9, trans, <<2::unsigned-8, savepoint::little-size(2)-unit(8)>>)
  end

  defp encode_isolation_level(isolation_level) do
    case isolation_level do
      :read_uncommitted -> 0x01
      :read_committed -> 0x02
      :repeatable_read -> 0x03
      :serializable -> 0x04
      :snapshot -> 0x05
      _no_change -> 0x00
    end
  end

  def encode_trans(request_type, trans, request_payload) do
    # Transaction Descriptor header
    header_type = <<2::little-size(2)-unit(8)>>
    trans_size = byte_size(trans)
    padding = 8 - trans_size
    transaction_descriptor = trans <> <<0::size(padding)-unit(8)>>
    outstanding_request_count = <<1::little-size(4)-unit(8)>>

    td_header = header_type <> transaction_descriptor <> outstanding_request_count

    td_header_len = byte_size(td_header) + 4
    td_header = <<td_header_len::little-size(4)-unit(8)>> <> td_header

    headers = td_header
    total_length = byte_size(headers) + 4
    all_headers = <<total_length::little-size(32)>> <> headers

    data = all_headers <> <<request_type::little-size(2)-unit(8), request_payload::binary>>

    encode_packets(0x0E, data)
  end

  defp encode_rpc(:sp_executesql, params) do
    <<0xFF, 0xFF, @tds_sp_executesql::little-size(2)-unit(8), 0x00, 0x00>> <>
      encode_rpc_params(params, "")
  end

  defp encode_rpc(:sp_prepare, params) do
    <<0xFF, 0xFF, @tds_sp_prepare::little-size(2)-unit(8), 0x00, 0x00>> <>
      encode_rpc_params(params, "")
  end

  defp encode_rpc(:sp_execute, params) do
    param_data =
      params
      |> Enum.map(fn
        %{name: "@handle"} = p ->
          # WARNING: This is not documented in official MS-TDS documentation!!!
          # if we use ProcIDSwitch == 0xFFFF and ProcID == 12 then
          # @handle parameter name must be ommited from RPC ParameterMetadata
          # for that parameter. Otherwise RPC will fail and we must use ProceName
          # instead. But we want to avoid execution overhead with named approach
          # hence ommiting @handle from parameter name
          %{p | name: ""}

        p ->
          # other paramters should be named
          p
      end)
      |> encode_rpc_params("")

    <<
      0xFFFF::size(2)-unit(8),
      @tds_sp_execute::little-size(2)-unit(8),
      0x00::size(2)-unit(8),
      param_data::binary
    >>
  end

  defp encode_rpc(:sp_unprepare, params) do
    <<0xFF, 0xFF, @tds_sp_unprepare::little-size(2)-unit(8), 0x00, 0x00>> <>
      encode_rpc_params(params, "")
  end

  # Finished processing params
  defp encode_rpc_params([], ret), do: ret

  defp encode_rpc_params([%Tds.Parameter{} = param | tail], ret) do
    p = encode_rpc_param(param)
    encode_rpc_params(tail, ret <> p)
  end

  defp encode_rpc_param(%Tds.Parameter{name: name} = param) do
    p_name = UCS2.from_string(name)
    p_flags = param |> Parameter.option_flags()
    {type_code, type_data, type_attr} = Types.encode_data_type(param)

    p_meta_data = <<byte_size(name)>> <> p_name <> p_flags <> type_data

    p_meta_data <> Types.encode_data(type_code, param.value, type_attr)
  end

  def encode_header(type, data, id, status) do
    length = byte_size(data) + 8
    # id::unsigned-size(8) below basicaly deals overflow e.g. rem(id, 255)
    <<type, status, length::size(16), 0::size(16), id::unsigned-size(8), 0>>
  end

  @spec encode_packets(integer, binary, non_neg_integer) :: [binary, ...]
  def encode_packets(type, binary, id \\ 1)

  def encode_packets(_type, <<>>, _) do
    []
  end

  def encode_packets(
        type,
        <<data::binary-size(@tds_pack_data_size)-unit(8), tail::binary>>,
        id
      ) do
    status = if byte_size(tail) > 0, do: 0, else: 1
    packet = [encode_header(type, data, id, status), data]
    [packet | encode_packets(type, tail, id + 1)]
  end

  def encode_packets(type, data, id) do
    header = encode_header(type, data, id, 1)
    [header <> data]
  end
end
