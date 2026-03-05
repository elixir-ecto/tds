defmodule Tds.Type.RegistryTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Registry

  defmodule FakeInteger do
    @behaviour Tds.Type

    def type_codes, do: [0x26, 0x38]
    def type_names, do: [:integer]
    def decode_metadata(r), do: {:ok, %{}, r}
    def decode(nil, _), do: nil
    def decode(_, _), do: 42
    def encode(v, _), do: {0x26, <<>>, <<v>>}
    def param_descriptor(_, _), do: "int"
    def infer(v) when is_integer(v), do: {:ok, %{}}
    def infer(_), do: :skip
  end

  defmodule FakeString do
    @behaviour Tds.Type

    def type_codes, do: [0xE7]
    def type_names, do: [:string]
    def decode_metadata(r), do: {:ok, %{}, r}
    def decode(nil, _), do: nil
    def decode(d, _), do: d
    def encode(v, _), do: {0xE7, <<>>, v}
    def param_descriptor(_, _), do: "nvarchar(max)"
    def infer(v) when is_binary(v), do: {:ok, %{}}
    def infer(_), do: :skip
  end

  defmodule UserOverride do
    @behaviour Tds.Type

    def type_codes, do: [0x26]
    def type_names, do: [:integer]
    def decode_metadata(r), do: {:ok, %{custom: true}, r}
    def decode(nil, _), do: nil
    def decode(_, _), do: :custom_int
    def encode(v, _), do: {0x26, <<>>, <<v>>}
    def param_descriptor(_, _), do: "int"
    def infer(v) when is_integer(v), do: {:ok, %{custom: true}}
    def infer(_), do: :skip
  end

  setup do
    {:ok, registry: Registry.new([], [FakeInteger, FakeString])}
  end

  describe "handler_for_code/2" do
    test "finds handler by type code", %{registry: reg} do
      assert {:ok, FakeInteger} = Registry.handler_for_code(reg, 0x26)
      assert {:ok, FakeInteger} = Registry.handler_for_code(reg, 0x38)
      assert {:ok, FakeString} = Registry.handler_for_code(reg, 0xE7)
    end

    test "returns error for unknown code", %{registry: reg} do
      assert :error = Registry.handler_for_code(reg, 0x00)
    end
  end

  describe "handler_for_name/2" do
    test "finds handler by atom name", %{registry: reg} do
      assert {:ok, FakeInteger} = Registry.handler_for_name(reg, :integer)
      assert {:ok, FakeString} = Registry.handler_for_name(reg, :string)
    end

    test "returns error for unknown name", %{registry: reg} do
      assert :error = Registry.handler_for_name(reg, :unknown)
    end
  end

  describe "user type override" do
    test "user handler overrides built-in for same type code" do
      reg = Registry.new([UserOverride], [FakeInteger, FakeString])
      assert {:ok, UserOverride} = Registry.handler_for_code(reg, 0x26)
    end

    test "user handler overrides built-in for same type name" do
      reg = Registry.new([UserOverride], [FakeInteger, FakeString])
      assert {:ok, UserOverride} = Registry.handler_for_name(reg, :integer)
    end

    test "non-overridden types still work" do
      reg = Registry.new([UserOverride], [FakeInteger, FakeString])
      assert {:ok, FakeString} = Registry.handler_for_code(reg, 0xE7)
    end
  end

  describe "infer/2" do
    test "infers integer handler from integer value",
         %{registry: reg} do
      assert {:ok, FakeInteger, %{}} = Registry.infer(reg, 42)
    end

    test "infers string handler from binary value",
         %{registry: reg} do
      assert {:ok, FakeString, %{}} = Registry.infer(reg, "hello")
    end

    test "returns error for unmatchable value",
         %{registry: reg} do
      assert :error = Registry.infer(reg, {:some, :tuple})
    end

    test "user types checked before built-ins" do
      reg = Registry.new([UserOverride], [FakeInteger, FakeString])

      assert {:ok, UserOverride, %{custom: true}} =
               Registry.infer(reg, 42)
    end
  end
end
