defmodule Tds.Type.BooleanTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Boolean

  describe "type_codes/0" do
    test "returns bit and bitn codes" do
      assert Boolean.type_codes() == [0x32, 0x68]
    end
  end

  describe "type_names/0" do
    test "returns :boolean" do
      assert Boolean.type_names() == [:boolean]
    end
  end

  describe "decode_metadata/1 for fixed bit (0x32)" do
    test "reads no additional bytes" do
      input = <<0x32, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 1}}, <<0xAA, 0xBB>>} =
               Boolean.decode_metadata(input)
    end
  end

  describe "decode_metadata/1 for bitn (0x68)" do
    test "reads 1-byte length" do
      input = <<0x68, 0x01, 0xCC, 0xDD>>

      assert {:ok, %{data_reader: :bytelen}, <<0xCC, 0xDD>>} =
               Boolean.decode_metadata(input)
    end
  end

  describe "decode/2" do
    test "nil returns nil" do
      assert Boolean.decode(nil, %{}) == nil
    end

    test "<<0x00>> returns false" do
      assert Boolean.decode(<<0x00>>, %{}) == false
    end

    test "<<0x01>> returns true" do
      assert Boolean.decode(<<0x01>>, %{}) == true
    end

    test "any non-zero byte returns true" do
      assert Boolean.decode(<<0xFF>>, %{}) == true
    end
  end

  describe "encode/2" do
    test "nil produces bitn null encoding" do
      {type_code, meta, value} = Boolean.encode(nil, %{})

      assert type_code == 0x68
      assert IO.iodata_to_binary(meta) == <<0x68, 0x01>>
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "true produces bitn with 0x01" do
      {type_code, meta, value} = Boolean.encode(true, %{})

      assert type_code == 0x68
      assert IO.iodata_to_binary(meta) == <<0x68, 0x01>>
      assert IO.iodata_to_binary(value) == <<0x01, 0x01>>
    end

    test "false produces bitn with 0x00" do
      {type_code, meta, value} = Boolean.encode(false, %{})

      assert type_code == 0x68
      assert IO.iodata_to_binary(meta) == <<0x68, 0x01>>
      assert IO.iodata_to_binary(value) == <<0x01, 0x00>>
    end
  end

  describe "param_descriptor/2" do
    test "returns bit descriptor" do
      assert Boolean.param_descriptor(true, %{}) == "bit"
      assert Boolean.param_descriptor(false, %{}) == "bit"
      assert Boolean.param_descriptor(nil, %{}) == "bit"
    end
  end

  describe "infer/1" do
    test "true infers as boolean" do
      assert {:ok, %{}} = Boolean.infer(true)
    end

    test "false infers as boolean" do
      assert {:ok, %{}} = Boolean.infer(false)
    end

    test "integer skips" do
      assert :skip = Boolean.infer(42)
    end

    test "string skips" do
      assert :skip = Boolean.infer("hello")
    end
  end
end
