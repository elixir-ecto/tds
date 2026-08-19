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

  test "extracts unique constraint name from en-US error 2627" do
    message =
      "Violation of UNIQUE KEY constraint 'UQ_users_email'. Details: key violation (key value string = (email=foo@bar.com))."

    assert [unique: "UQ_users_email"] = Tds.Error.get_constraint_violations(2627, message)
  end

  test "extracts unique index name from en-US error 2601" do
    message =
      "Cannot insert duplicate key row in object 'dbo.users' with unique index 'IX_users_email'. The duplicate key value is (foo@bar.com)."

    assert [unique: "IX_users_email"] = Tds.Error.get_constraint_violations(2601, message)
  end

  test "returns no constraints for unknown error code" do
    assert [] = Tds.Error.get_constraint_violations(9999, "some error")
  end
end
