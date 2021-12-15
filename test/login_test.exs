defmodule LoginTest do
  use ExUnit.Case, async: true

  import Tds.TestHelper, only: [opts: 0]

  test "Login with sql server authentication" do
    # :dbg.tracer()
    # :dbg.p(:all,:c)
    # :dbg.tpl(Tds.Messages,:parse,:x)
    # :dbg.tpl(Tds.Protocol,:message,:x)
    {:ok, pid} = Tds.start_link(opts())
    assert {:ok, _} = Tds.query(pid, "SELECT 1", [])
  end
end
