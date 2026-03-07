# PLP chunk reassembly: current binary concat vs iolist accumulation.
# Run: mix run bench/plp_bench.exs
#
# Baseline results (2026-03-05)
# Machine: Apple M4 Pro, 48 GB, macOS
# Elixir 1.18.1, Erlang/OTP 27.2, JIT enabled
#
# Name                            ips        average  deviation         median         99th %
# 1MB new (iolist)            43.15 K       23.17 us    +-10.68%      23.38 us       29.21 us
# 1MB current (concat)         5.38 K      186.02 us    +-21.73%     183.63 us      291.98 us
# 10MB new (iolist)            3.44 K      290.93 us    +-21.21%     280.71 us      730.41 us
# 10MB current (concat)        0.49 K     2026.15 us     +-6.40%    2018.46 us     2400.42 us
#
# Summary: iolist is 8x faster at 1MB and 7x faster at 10MB
#
# Memory usage:
# 1MB new (iolist)             18.13 KB
# 1MB current (concat)         35.44 KB - 1.96x
# 10MB new (iolist)           170.70 KB
# 10MB current (concat)       357.38 KB - 2.10x

defmodule PLPBench do
  # Current approach: buf <> :binary.copy(chunk)
  def decode_plp_current(<<0::little-unsigned-32, _rest::binary>>, buf),
    do: buf

  def decode_plp_current(
        <<size::little-unsigned-32,
          chunk::binary-size(size),
          rest::binary>>,
        buf
      ) do
    decode_plp_current(rest, buf <> :binary.copy(chunk))
  end

  # New approach: iolist accumulation
  def decode_plp_iolist(<<0::little-unsigned-32, _rest::binary>>, acc),
    do: :lists.reverse(acc) |> IO.iodata_to_binary()

  def decode_plp_iolist(
        <<size::little-unsigned-32,
          chunk::binary-size(size),
          rest::binary>>,
        acc
      ) do
    decode_plp_iolist(rest, [chunk | acc])
  end

  def build_plp_payload(total_size, chunk_size) do
    chunk = :crypto.strong_rand_bytes(chunk_size)
    num_chunks = div(total_size, chunk_size)

    chunks =
      for _ <- 1..num_chunks, into: <<>> do
        <<chunk_size::little-unsigned-32>> <> chunk
      end

    chunks <> <<0::little-unsigned-32>>
  end
end

payload_1mb = PLPBench.build_plp_payload(1_048_576, 4096)
payload_10mb = PLPBench.build_plp_payload(10_485_760, 4096)

Benchee.run(
  %{
    "1MB current (concat)" => fn ->
      PLPBench.decode_plp_current(payload_1mb, <<>>)
    end,
    "1MB new (iolist)" => fn ->
      PLPBench.decode_plp_iolist(payload_1mb, [])
    end,
    "10MB current (concat)" => fn ->
      PLPBench.decode_plp_current(payload_10mb, <<>>)
    end,
    "10MB new (iolist)" => fn ->
      PLPBench.decode_plp_iolist(payload_10mb, [])
    end
  },
  warmup: 1,
  time: 5,
  memory_time: 2
)
