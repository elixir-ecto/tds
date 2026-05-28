defmodule ErrorTest do
  use ExUnit.Case, async: true

  test "raises a Tds.Error with a string message" do
    assert_raise Tds.Error, "Some wild error.", fn ->
      raise Tds.Error, "Some wild error."
    end
  end

  test "raises a Tds.Error with Mssql infos" do
    assert_raise Tds.Error, "Line 4 (Error 8): something bad", fn ->
      raise Tds.Error, line_number: 4, number: 8, msg_text: "something bad"
    end
  end

  test "combines :message and :mssql when both are populated" do
    error = %Tds.Error{
      message: "Connection closed.",
      mssql: %{line_number: 1, number: 18_456, msg_text: "Login failed for user 'sa'"}
    }

    assert Tds.Error.message(error) ==
             "Connection closed. Line 1 (Error 18456): Login failed for user 'sa'"
  end

  test "raises a Tds.Error with a default message as a fallback" do
    # no arguments
    assert_raise Tds.Error, "An error occured.", fn ->
      raise Tds.Error
    end

    # weird arguments
    assert_raise Tds.Error, "An error occured.", fn ->
      raise Tds.Error, profession: "crocodile hunter"
    end
  end
end
