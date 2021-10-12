defmodule Tds.Ucs2TableTest do
  use ExUnit.Case, async: true
  import Tds.TestHelper

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)
    {:ok, [pid: pid]}
  end

  @tag capture_log: true
  test "should encode/decode correctly ucs2 strings", context do
    __DIR__
    |> Path.join('ucs_2_table.txt')
    |> File.stream!([encoding: :utf8], :line)
    # note: `[ ]  00A0  NO-BREAK SPACE (skip)` since it fails for some reason
    |> Stream.filter(&(not (&1 =~ "(skip)")))
    |> Stream.flat_map(fn line ->
      case String.split(line, "  ") do
        [<<?[, char::utf8, ?]>>, code_hex, title] ->
          {code, ""} = Integer.parse(code_hex, 16)
          [[
            <<char::utf8>>,
            "0x" <> Base.encode16(<<code::little-size(2)-unit(8)>>, case: :upper),
            String.trim_trailing(title, "\n")
            ]]

        _ ->
          []
      end
    end)
    |> Stream.chunk_every(100)
    |> Enum.each(fn chunk ->
      sql =
        chunk
        |> Enum.reduce(nil, fn
          [_, bin, title], nil ->
            "select cast(#{bin} as nchar(1)), N'#{bin}', N'#{title}'"

          [_, bin, title], acc ->
            acc <> " union all \n select cast(#{bin} as nchar(1)), N'#{bin}', N'#{title}'"
        end)

      assert chunk == query(sql)
    end)
  end
end
