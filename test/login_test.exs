defmodule LoginTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  setup do
    hostname =
      Application.fetch_env!(:tds, :opts)
      |> Keyword.get(:hostname)

    {:ok,
     [
       options: [
         hostname: hostname,
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
             opts = [username: "sa", password: "wrong"] ++ context[:options]
             assert_start_and_killed(opts)
           end) =~
             "(Tds.Error) Line 1 (Error 18456): Login failed for user 'sa'"
  end

  @tag :login
  @tag :tls
  test "login with valid sql login over tsl", context do
    opts =
      Application.fetch_env!(:tds, :opts) ++
        [ssl: true, ssl_opts: []]
        # [ssl: true, ssl_opts: [log_debug: true, log_level: :debug]]

    assert {:ok, pid} = Tds.start_link(opts ++ context[:options])
    assert {:ok, %Tds.Result{}} = Tds.query(pid, "SELECT 1", [])
  end

  @tag :login
  @tag :tls
  test "login with non existing sql server authentication over tls", context do
    assert capture_log(fn ->
             opts =
               [username: "sa", password: "wrong"] ++
                 context[:options] ++
                 [ssl: true, ssl_opts: [log_debug: true]]

             assert_start_and_killed(opts)
           end) =~
             "(Tds.Error) Line 1 (Error 18456): Login failed for user 'sa'"
  end

  defp assert_start_and_killed(opts) do
    Process.flag(:trap_exit, true)

    case Tds.start_link(opts) do
      {:ok, pid} -> assert_receive {:EXIT, ^pid, :killed}, 1_000
      {:error, :killed} -> :ok
    end
  end
end
