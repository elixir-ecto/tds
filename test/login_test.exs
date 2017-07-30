defmodule LoginTest do
  use ExUnit.Case, async: true

  test "Login with sql server authentication" do
    opts = Application.fetch_env!(:mssql, :opts)

    assert {:ok, _pid} = Tds.start_link(opts)
  end
end
