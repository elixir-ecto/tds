# Benchmarks for type system decode/encode throughput.
# Run: mix run bench/type_system_bench.exs
#
# Requires benchee: add {:benchee, "~> 1.3", only: :dev, runtime: false}
# to mix.exs deps if not present.
#
# Baseline results (2026-03-05)
# Machine: Apple M4 Pro, 48 GB, macOS
# Elixir 1.18.1, Erlang/OTP 27.2, JIT enabled
#
# Name                                 ips        average  deviation         median         99th %
# decode_data integer           18822.86 K      0.0531 us  +-6681.70%     0.0420 us      0.0840 us
# decode_data string              101.25 K        9.88 us    +-56.44%       9.25 us       20.13 us
# encode 1000 decimal params        1.88 K      530.63 us     +-3.18%     527.25 us      582.46 us
#
# Memory usage:
# decode_data integer             0.00014 MB
# decode_data string               0.0271 MB - 187.21x
# encode 1000 decimal params         1.99 MB - 13736.68x
#
# Binary match context optimization (ERL_COMPILER_OPTIONS=bin_opt_info):
#
# OPTIMIZED (match context reused):
#   types.ex:218  - decode_info variable type dispatching
#   types.ex:337  - decode_data fixed types (13 match context reuses)
#   types.ex:543  - decode_data PLP reader (2 match context reuses)
#   types.ex:590  - decode_plp_chunk
#   types.ex:623  - decode_char
#   tokens.ex:50-61 - token dispatch (10 match context reuses)
#   tokens.ex:564 - row decoding
#   prelogin.ex:197-256 - prelogin option parsing (7 reuses)
#   packet.ex:44-56 - packet header parsing (3 reuses)
#   uuid.ex:121  - UUID byte reordering
#
# NOT OPTIMIZED:
#   types.ex:280  - decode_info Enum.reduce for collation (remote call)
#   types.ex:297  - decode_info Enum.reduce for variant (remote call)
#   types.ex:610  - decode_data variant Kernel.inspect (remote call)
#   types.ex:617  - decode_data variant Kernel.inspect (remote call)
#   types.ex:634  - decode_char -> Tds.Utils.decode_chars (remote call)
#   types.ex:638  - decode_nchar -> UCS2.to_string (remote call)
#   types.ex:642  - decode_xml -> UCS2.to_string (remote call)
#   types.ex:1365 - encode_plp_chunk (unsuitable binary match start)
#   tokens.ex:572 - Tds.Types.decode_data remote call
#   prelogin.ex:264-301 - decode_data/3 (unsuitable binary match start)

alias Tds.Types
alias Tds.Parameter

defmodule TypeBench.Fixtures do
  import Tds.Protocol.Constants

  def integer_decode_input do
    type_info = %{
      data_type: :fixed,
      data_type_code: tds_type(:int),
      length: 4,
      data_type_name: :int
    }

    data = <<42, 0, 0, 0, 0xFF>>
    {type_info, data}
  end

  def string_decode_input do
    value = String.duplicate("hello", 100)
    ucs2 = Tds.Encoding.UCS2.from_string(value)
    size = byte_size(ucs2)

    type_info = %{
      data_type: :variable,
      data_type_code: tds_type(:nvarchar),
      data_reader: :shortlen,
      collation: %Tds.Protocol.Collation{codepage: :RAW},
      length: size
    }

    data = <<size::little-unsigned-16>> <> ucs2 <> <<0xFF>>
    {type_info, data}
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

{int_info, int_data} = TypeBench.Fixtures.integer_decode_input()
{str_info, str_data} = TypeBench.Fixtures.string_decode_input()
params = TypeBench.Fixtures.decimal_encode_params()

Benchee.run(
  %{
    "decode_data integer" => fn ->
      Types.decode_data(int_info, int_data)
    end,
    "decode_data string" => fn ->
      Types.decode_data(str_info, str_data)
    end,
    "encode 1000 decimal params" => fn ->
      Enum.each(params, &Types.encode_data_type/1)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
