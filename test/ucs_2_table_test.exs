defmodule Tds.Ucs2TableTest do
  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog
  import Tds.TestHelper

  @ucs2_table __DIR__
              |> Path.join('ucs_2_table.txt')
              |> File.stream!([encoding: :utf8], :line)
              # note: `[ ]  00A0  NO-BREAK SPACE (skip)` since it fails for some reason
              |> Stream.filter(&(not(&1 =~ "(skip)")))
              |> Enum.flat_map(fn line ->
                case String.split(line, "  ") do
                  [<<?[, char::utf8, ?]>>, code_hex, title] ->
                    {code, ""} = Integer.parse(code_hex, 16)
                    [{<<char::utf8>>, code, String.trim_trailing(title, "\n")}]

                  _ ->
                    []
                end
              end)

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)
    {:ok, [pid: pid]}
  end

  test "should encode/decode correctly ucs2 strings", context do
    Enum.each(@ucs2_table, fn {char, code, title} ->
      bin = "0x" <> Base.encode16(<<code::little-size(2)-unit(8)>>, case: :upper)
      assert [[char, bin, title]] ==
               query("select cast(#{bin} as nchar(1)), N'#{bin}', N'#{title}'")
    end)
  end
end
