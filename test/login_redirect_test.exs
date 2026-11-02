defmodule LoginRedirectTest do
  use ExUnit.Case, async: true

  import Tds.Messages

  @moduletag :capture_log

  # Azure SQL may answer the login with a routing ENVCHANGE that redirects the
  # client to another node. When connecting to that node fails (e.g. error 40613,
  # "database is not currently available"), the error must come back in the same
  # {:error, error, state} shape as any other login error, so that the connection
  # reports it instead of crashing with a CaseClauseError in decode/2.
  test "a failed connect to the redirect target is returned as a login error" do
    {:ok, listener} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(listener)
    :ok = :gen_tcp.close(listener)

    state = %Tds.Protocol{opts: [hostname: "gateway.invalid", ssl: false, timeout: 1_000]}
    redirect = msg_loginack(redirect: %{hostname: "127.0.0.1", port: port})

    assert {:error, %Tds.Error{message: "tcp connect: econnrefused"}, ^state} =
             Tds.Protocol.message(:login, redirect, state)
  end
end
