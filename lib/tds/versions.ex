defmodule Tds.Version do
  import Tds.Protocol.Grammar

  defstruct version: 0x74000004, str_version: "7.4"

  @versions [
    {0x71000001, "7.1"},
    {0x72090002, "7.2"},
    {0x730A0003, "7.3.A"},
    {0x730B0003, "7.3.B"},
    {0x74000004, "7.4"}
  ]

  def decode(<<key::little-dword>>) do
    @versions
    |> List.keyfind(key, 0, "7.4")
  end

  def encode(ver) do
    val =
      @versions
      |> List.keyfind(ver, 1, 0x74000004)

    <<val::little-dword>>
  end
end
