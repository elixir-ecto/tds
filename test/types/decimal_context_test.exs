defmodule Tds.Types.DecimalContextTest do
  use ExUnit.Case, async: true

  alias Tds.Parameter
  alias Tds.Types

  @tds_data_type_decimaln 0x6A

  setup do
    context = %Decimal.Context{Decimal.Context.get() | precision: 7}
    Decimal.Context.set(context)
    {:ok, context: context}
  end

  test "decode_decimal/3 leaves the Decimal.Context untouched", %{context: context} do
    assert Types.decode_decimal(15, 2, <<1, 1000::little-32>>) == Decimal.new("10.00")
    assert Decimal.Context.get() == context
  end

  test "encoding decimal parameters leaves the Decimal.Context untouched", %{context: context} do
    param = %Parameter{name: "@1", value: Decimal.new("123456789012345678901.5"), type: :decimal}

    assert {_type, _data, precision: 22, scale: 1} = Types.encode_decimal_type(param)
    assert Types.encode_decimal_descriptor(param) == "decimal(22, 1)"
    assert {_type, _data, _attr} = Types.encode_float_type(param)

    Types.encode_data(@tds_data_type_decimaln, param.value, precision: 22, scale: 1)

    assert Decimal.Context.get() == context
  end
end
