defmodule Tds.AccessTokenTest do
  use ExUnit.Case, async: false

  describe "Tds.Protocol.connect/1 with :access_token" do
    test "function is invoked and its token is used for the login" do
      {:ok, agent} = Agent.start_link(fn -> false end)

      opts =
        Tds.TestHelper.opts()
        |> Keyword.put(:access_token, fn ->
          Agent.update(agent, fn _ -> true end)
          {:ok, "token-from-function"}
        end)
        |> Keyword.drop([:username, :password])

      # The local server does not accept Entra ID tokens: the login must
      # fail gracefully with a server error, not with a token resolution
      # error, proving the token traveled inside the LOGIN7 message
      assert {:error, %Tds.Error{} = err} = Tds.Protocol.connect(opts)
      assert Agent.get(agent, & &1)
      refute Exception.message(err) =~ "access token"
    end

    test "function returning an error fails fast without opening a socket" do
      opts = [hostname: "127.0.0.1", access_token: fn -> {:error, :tenant_not_found} end]

      assert {:error, %Tds.Error{} = err} = Tds.Protocol.connect(opts)
      assert err.message =~ ":tenant_not_found"
    end

    test "function returning an invalid token fails fast" do
      for value <- [{:ok, ""}, {:ok, 123}] do
        opts = [hostname: "127.0.0.1", access_token: fn -> value end]

        assert {:error, %Tds.Error{} = err} = Tds.Protocol.connect(opts)
        assert err.message =~ "non empty binary"
      end
    end

    test "function returning an invalid shape fails fast" do
      opts = [hostname: "127.0.0.1", access_token: fn -> "raw-token" end]

      assert {:error, %Tds.Error{} = err} = Tds.Protocol.connect(opts)
      assert err.message =~ "{:ok, token} | {:error, reason}"
    end

    test "function raising an exception is wrapped" do
      opts = [hostname: "127.0.0.1", access_token: fn -> raise "boom" end]

      assert {:error, %Tds.Error{} = err} = Tds.Protocol.connect(opts)
      assert err.message =~ "boom"
    end

    test "non zero arity functions are rejected" do
      opts = [hostname: "127.0.0.1", access_token: &String.length/1]

      assert {:error, %Tds.Error{} = err} = Tds.Protocol.connect(opts)
      assert err.message =~ "zero arity function"
    end

    test "invalid values are rejected" do
      for value <- [123, :token, {"m", "f"}] do
        opts = [hostname: "127.0.0.1", access_token: value]

        assert {:error, %Tds.Error{}} = Tds.Protocol.connect(opts)
      end
    end
  end
end
