defmodule Tds.TypeTest do
  use ExUnit.Case, async: true

  defmodule MockHandler do
    @behaviour Tds.Type

    @impl true
    def type_codes, do: [0xFF]

    @impl true
    def type_names, do: [:mock]

    @impl true
    def decode_metadata(<<rest::binary>>),
      do: {:ok, %{data_reader: :bytelen, length: 1}, rest}

    @impl true
    def decode(nil, _meta), do: nil
    def decode(<<val>>, _meta), do: val

    @impl true
    def encode(nil, _meta), do: {0xFF, <<0xFF, 0x00>>, <<0x00>>}
    def encode(val, _meta), do: {0xFF, <<0xFF, 0x01>>, <<0x01, val>>}

    @impl true
    def param_descriptor(_value, _meta), do: "mock"

    @impl true
    def infer(val) when is_integer(val) and val in 0..255,
      do: {:ok, %{}}

    def infer(_), do: :skip
  end

  describe "behaviour contract" do
    test "mock handler compiles and implements all callbacks" do
      assert MockHandler.type_codes() == [0xFF]
      assert MockHandler.type_names() == [:mock]
    end

    test "decode_metadata returns ok tuple with metadata and rest" do
      assert {:ok, %{data_reader: :bytelen}, <<0xAA>>} =
               MockHandler.decode_metadata(<<0xAA>>)
    end

    test "decode nil returns nil" do
      assert MockHandler.decode(nil, %{}) == nil
    end

    test "decode binary returns value" do
      assert MockHandler.decode(<<42>>, %{}) == 42
    end

    test "encode returns {type_code, meta_bin, value_bin}" do
      {0xFF, _meta, _val} = MockHandler.encode(42, %{})
    end

    test "param_descriptor returns string" do
      assert MockHandler.param_descriptor(42, %{}) == "mock"
    end

    test "infer returns ok or skip" do
      assert {:ok, %{}} = MockHandler.infer(42)
      assert :skip = MockHandler.infer("not a byte")
    end
  end
end
