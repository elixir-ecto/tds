defmodule Tds.Protocol do

  import Tds.Utils
  import Tds.Messages
  
  alias Tds.Parameter

  def prelogin(%{opts: opts} = s) do

    msg = msg_prelogin(params: opts)
    case msg_send(msg, s) do
      :ok ->
        {:noreply,  %{s | state: :prelogin}}
      {:error, reason} ->
        error(%Tds.Error{message: "tcp send: #{reason}"}, s)
    end
  end

  def login(%{opts: opts} = s) do
    msg = msg_login(params: opts)
    case msg_send(msg, s) do
      :ok ->
        {:noreply,  %{s | state: :login}}
      {:error, reason} ->
        error(%Tds.Error{message: "tcp send: #{reason}"}, s)
    end
  end

  def send_query(statement, s) do
    #IO.inspect statement
    msg = msg_sql(query: statement)

    case send_to_result(msg, s) do
      {:ok, s} ->
        {:ok, %{s | statement: nil, state: :executing}}
      err ->
        err
    end
  end

  def send_param_query(statement, params, s) do
    param_desc = params |> Enum.map(fn(%Parameter{} = param) -> 
      Tds.Types.encode_param_descriptor(param)
    end)
    param_desc = param_desc
      |> Enum.join(", ")

    msg = msg_rpc(proc: :sp_executesql, params: [%Parameter{value: statement, type: :string}, %Parameter{value: param_desc, type: :string}] ++ params)
    case send_to_result(msg, s) do
      {:ok, s} ->
        {:ok, %{s | statement: nil, state: :executing}}
      err ->
        err
    end
  end

  def send_proc(proc, params, s) do
    msg = msg_rpc(proc: proc, params: params)
    case send_to_result(msg, s) do
      {:ok, s} ->
        {:ok, %{s | statement: nil, state: :executing}}
      err ->
        err
    end
  end

  def send_attn(s) do
    msg = msg_attn()
    case send_to_result(msg, s) do
      {:ok, s} ->
        {:ok, %{s | statement: nil, state: :attn}}
      err ->
        err
    end
  end

  ## SERVER Packet Responses

  def message(:prelogin, _state) do

  end

  def message(:login, msg_login_ack(), %{opts: opts, tail: _tail, opts: opts} = s) do
    s = %{s | opts: clean_opts(opts)}
    reply(:ok, s)
    ready(s)
  end

  ## executing

  def message(:executing, msg_sql_result(columns: columns, rows: rows, done: done), %{} = s) do
    if columns != nil do
      columns = Enum.reduce(columns, [], fn (col, acc) -> [col[:name]|acc] end) |> Enum.reverse
    end
    num_rows = done.rows;
    if rows != nil do
      rows = Enum.reverse rows
    end
    if num_rows == 0 && rows == nil do
      rows = []
    end
    result = %Tds.Result{columns: columns, rows: rows, num_rows: num_rows}
    reply(result, s)
    ready(s)
  end

  def message(:executing, msg_trans(trans: trans), %{} = s) do
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}
    reply(result, s)
    ready(%{s |env: %{trans: trans}})
  end

  ## Error
  def message(_, msg_error(e: e), %{} = s) do
    reply(%Tds.Error{mssql: e}, s)
    ready(s)
  end

  def message(:attn, _, %{} = s) do
    :erlang.cancel_timer(s.attn_timer)
    result = %Tds.Result{columns: [], rows: [], num_rows: 0}
    reply(result, s)
    ready(s)
  end

  defp msg_send(msg, %{sock: {mod, sock}, env: env}) do 
    data = encode_msg(msg, env)
    mod.send(sock, data)
  end

  defp send_to_result(msg, s) do
    case msg_send(msg, s) do
      :ok ->
        {:ok, s}
      {:error, reason} ->
        {:error, %Tds.Error{message: "tcp send: #{reason}"} , s}
    end
  end

  defp clean_opts(opts) do
    Keyword.put(opts, :password, :REDACTED)
  end

end
