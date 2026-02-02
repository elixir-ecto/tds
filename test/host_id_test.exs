defmodule HostIdTest do
  use ExUnit.Case, async: true

  import Tds.TestHelper, only: [opts: 0]

  test "Check that SELECT HOST_ID() matches System.pid()" do
    {:ok, conn} = Tds.start_link(opts())
    {:ok, %Tds.Result{rows: [[host_id]]}} = Tds.query(conn, "SELECT HOST_ID()", [])

    pid = System.pid()
    assert pid === String.trim(host_id)
  end
end
