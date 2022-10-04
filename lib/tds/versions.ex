defmodule Tds.Version do
  @moduledoc false

  import Tds.Protocol.Grammar

  @default_version :v7_4
  @default_code 0x74000004

  @versions [
    {0x71000001, :v7_1},
    {0x72090002, :v7_2},
    {0x730A0003, :v7_3_a},
    {0x730B0003, :v7_3_b},
    {0x74000004, :v7_4}
  ]

  def decode(<<key::little-dword()>>) do
    List.keyfind(@versions, key, 0, @default_version)
  end

  def encode(ver) do
    val = List.keyfind(@versions, ver, 1, @default_code)
    <<val::little-dword()>>
  end
end
