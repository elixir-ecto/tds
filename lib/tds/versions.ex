defmodule Tds.Version do
  import Tds.Protocol.Grammar

  @default_version :v7_4
  @default_code 0x74000004

  defstruct code: @default_code, version: @default_version

  @versions [
    {0x71000001, :v7_1},
    {0x72090002, :v7_2},
    {0x730A0003, :v7_3_a},
    {0x730B0003, :v7_3_b},
    {0x74000004, :v7_4}
  ]

  def decode(<<key::little-dword>>) do
    @versions
    |> List.keyfind(key, 0, @default_version)
  end

  def encode(ver) do
    val =
      @versions
      |> List.keyfind(ver, 1, @default_code)

    <<val::little-dword>>
  end
end
