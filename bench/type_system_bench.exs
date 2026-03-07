# Benchmarks for type system decode/encode throughput.
# Run: mix run bench/type_system_bench.exs
#
# Requires benchee: add {:benchee, "~> 1.3", only: :dev, runtime: false}
# to mix.exs deps if not present.

alias Tds.Parameter
alias Tds.Type.{DataReader, Registry}

defmodule TypeBench.Fixtures do
  import Tds.Protocol.Constants

  @registry Tds.Type.Registry.new()

  def registry, do: @registry

  def integer_decode_input do
    {:ok, handler} =
      Registry.handler_for_code(@registry, tds_type(:int))

    meta = %{data_reader: {:fixed, 4}, handler: handler}
    data = <<42, 0, 0, 0, 0xFF>>
    {meta, data}
  end

  def string_decode_input do
    value = String.duplicate("hello", 100)
    ucs2 = Tds.Encoding.UCS2.from_string(value)
    size = byte_size(ucs2)

    {:ok, handler} =
      Registry.handler_for_code(@registry, tds_type(:nvarchar))

    meta = %{
      data_reader: :shortlen,
      collation: %Tds.Protocol.Collation{codepage: :RAW},
      encoding: :ucs2,
      length: size,
      handler: handler
    }

    data = <<size::little-unsigned-16>> <> ucs2 <> <<0xFF>>
    {meta, data}
  end

  def decimal_encode_params do
    for _ <- 1..1000 do
      %Parameter{
        name: "@1",
        value: Decimal.new("12345.6789"),
        type: :decimal
      }
    end
  end
end

{int_meta, int_data} = TypeBench.Fixtures.integer_decode_input()
{str_meta, str_data} = TypeBench.Fixtures.string_decode_input()
params = TypeBench.Fixtures.decimal_encode_params()
registry = TypeBench.Fixtures.registry()

Benchee.run(
  %{
    "decode integer" => fn ->
      {raw, _rest} = DataReader.read(int_meta.data_reader, int_data)
      int_meta.handler.decode(raw, int_meta)
    end,
    "decode string" => fn ->
      {raw, _rest} = DataReader.read(str_meta.data_reader, str_data)
      str_meta.handler.decode(raw, str_meta)
    end,
    "encode 1000 decimal params" => fn ->
      Enum.each(params, fn p ->
        {:ok, handler} = Registry.handler_for_name(registry, p.type)
        meta = %{type: p.type}
        handler.encode(p.value, meta)
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
