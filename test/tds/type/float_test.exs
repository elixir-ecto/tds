defmodule Tds.Type.FloatTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Float

  describe "type_codes/0" do
    test "returns real, float, and floatn codes" do
      codes = Float.type_codes()
      assert 0x3B in codes
      assert 0x3E in codes
      assert 0x6D in codes
      assert length(codes) == 3
    end
  end

  describe "type_names/0" do
    test "returns :float" do
      assert Float.type_names() == [:float]
    end
  end

  describe "decode_metadata/1" do
    test "real (0x3B) is fixed 4 bytes" do
      input = <<0x3B, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 4}}, <<0xAA, 0xBB>>} =
               Float.decode_metadata(input)
    end

    test "float (0x3E) is fixed 8 bytes" do
      input = <<0x3E, 0xAA, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 8}}, <<0xAA, 0xBB>>} =
               Float.decode_metadata(input)
    end

    test "floatn (0x6D) reads 1-byte length" do
      input = <<0x6D, 0x04, 0xCC, 0xDD>>

      assert {:ok, %{data_reader: :bytelen, length: 4}, <<0xCC, 0xDD>>} =
               Float.decode_metadata(input)
    end

    test "floatn (0x6D) with length 8" do
      input = <<0x6D, 0x08, 0xEE>>

      assert {:ok, %{data_reader: :bytelen, length: 8}, <<0xEE>>} =
               Float.decode_metadata(input)
    end
  end

  describe "decode/2" do
    test "nil returns nil" do
      assert Float.decode(nil, %{}) == nil
    end

    test "4-byte real (float-32) decodes 1.5" do
      data = <<1.5::little-float-32>>
      assert Float.decode(data, %{length: 4}) == 1.5
    end

    test "4-byte real (float-32) decodes 0.0" do
      data = <<0.0::little-float-32>>
      assert Float.decode(data, %{length: 4}) == 0.0
    end

    test "4-byte real (float-32) decodes negative" do
      data = <<-3.14::little-float-32>>
      result = Float.decode(data, %{length: 4})
      assert_in_delta result, -3.14, 0.001
    end

    test "8-byte float (float-64) decodes 1.5" do
      data = <<1.5::little-float-64>>
      assert Float.decode(data, %{length: 8}) == 1.5
    end

    test "8-byte float (float-64) decodes 0.0" do
      data = <<0.0::little-float-64>>
      assert Float.decode(data, %{length: 8}) == 0.0
    end

    test "8-byte float (float-64) decodes negative" do
      data = <<-3.14::little-float-64>>
      result = Float.decode(data, %{length: 8})
      assert_in_delta result, -3.14, 0.0000001
    end

    test "8-byte float (float-64) decodes large value" do
      data = <<1.0e100::little-float-64>>
      assert Float.decode(data, %{length: 8}) == 1.0e100
    end

    test "4-byte real without explicit length uses data size" do
      data = <<1.5::little-float-32>>
      assert Float.decode(data, %{}) == 1.5
    end

    test "8-byte float without explicit length uses data size" do
      data = <<1.5::little-float-64>>
      assert Float.decode(data, %{}) == 1.5
    end
  end

  describe "encode/2" do
    test "nil produces floatn null encoding" do
      {type_code, meta, value} = Float.encode(nil, %{})

      assert type_code == 0x6D
      assert IO.iodata_to_binary(meta) == <<0x08>>
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "positive float encodes as 8-byte float-64" do
      {type_code, meta, value} = Float.encode(1.5, %{})

      assert type_code == 0x6D
      assert IO.iodata_to_binary(meta) == <<0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, 1.5::little-float-64>>
    end

    test "zero encodes as 8-byte float-64" do
      {type_code, meta, value} = Float.encode(0.0, %{})

      assert type_code == 0x6D
      assert IO.iodata_to_binary(meta) == <<0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, 0.0::little-float-64>>
    end

    test "negative float encodes as 8-byte float-64" do
      {type_code, meta, value} = Float.encode(-3.14, %{})

      assert type_code == 0x6D
      assert IO.iodata_to_binary(meta) == <<0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, -3.14::little-float-64>>
    end

    test "large float encodes as 8-byte float-64" do
      {type_code, meta, value} = Float.encode(1.0e100, %{})

      assert type_code == 0x6D
      assert IO.iodata_to_binary(meta) == <<0x08>>

      assert IO.iodata_to_binary(value) ==
               <<0x08, 1.0e100::little-float-64>>
    end
  end

  describe "param_descriptor/2" do
    test "nil returns decimal(1,0)" do
      assert Float.param_descriptor(nil, %{}) == "decimal(1,0)"
    end

    test "float value returns float(53)" do
      assert Float.param_descriptor(1.5, %{}) == "float(53)"
    end

    test "negative float returns float(53)" do
      assert Float.param_descriptor(-3.14, %{}) == "float(53)"
    end

    test "zero float returns float(53)" do
      assert Float.param_descriptor(0.0, %{}) == "float(53)"
    end
  end

  describe "infer/1" do
    test "positive float infers" do
      assert {:ok, %{}} = Float.infer(1.5)
    end

    test "zero float infers" do
      assert {:ok, %{}} = Float.infer(0.0)
    end

    test "negative float infers" do
      assert {:ok, %{}} = Float.infer(-3.14)
    end

    test "integer skips" do
      assert :skip = Float.infer(42)
    end

    test "string skips" do
      assert :skip = Float.infer("3.14")
    end

    test "boolean skips" do
      assert :skip = Float.infer(true)
    end

    test "nil skips" do
      assert :skip = Float.infer(nil)
    end
  end
end
