defmodule LoginTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  setup do
    {:ok,
     [
       options: [
         database: "test",
         backoff_type: :stop,
         max_restarts: 0,
         show_sensitive_data_on_connection_error: true
       ]
     ]}
  end

  @tag :login
  test "login with sql server authentication", context do
    opts = Application.fetch_env!(:tds, :opts) ++ context[:options]
    {:ok, pid} = Tds.start_link(opts)
    assert {:ok, %Tds.Result{}} = Tds.query(pid, "SELECT 1", [])
  end

  @tag :login
  test "login with non existing sql server authentication", context do
    assert capture_log(fn ->
             opts = [username: "sa", password: "wrong"]
             assert_start_and_killed(opts ++ context[:options])
           end) =~ ~r"\*\* \(Tds.Error\) tcp connect: econnrefused"
  end

  @tag :manual
  @tag :login
  test "ssl", context do
    opts = Application.fetch_env!(:tds, :opts) ++ [ssl: true, timeout: 10_000]
    assert {:ok, pid} = Tds.start_link(opts ++ context[:options])
    assert {:ok, %Tds.Result{}} = Tds.query(pid, "SELECT 1", [])
  end

  defp assert_start_and_killed(opts) do
    Process.flag(:trap_exit, true)

    case Tds.start_link(opts) do
      {:ok, pid} -> assert_receive {:EXIT, ^pid, :killed}
      {:error, :killed} -> :ok
    end
  end
end
