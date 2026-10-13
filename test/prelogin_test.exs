defmodule PreloginTest do
  use ExUnit.Case, async: true

  alias Tds.Protocol.Prelogin

  @nonce :binary.copy(<<0xAB>>, 32)

  test "decode prelogin response requiring federated authentication" do
    # VERSION | ENCRYPTION(ON) | FEDAUTHREQUIRED(0x01) | NONCEOPT(32B)
    packet =
      <<0x00, 21::unsigned-16, 6::unsigned-16>> <>
        <<0x01, 27::unsigned-16, 1::unsigned-16>> <>
        <<0x06, 28::unsigned-16, 1::unsigned-16>> <>
        <<0x07, 29::unsigned-16, 32::unsigned-16>> <>
        <<0xFF>> <>
        <<4, 0, 10, 0, 0, 0>> <> <<0x01>> <> <<0x01>> <> @nonce

    s = %Tds.Protocol{opts: [ssl: :required]}

    assert {:encrypt, %{opts: opts}} = Prelogin.decode(packet, s)
    assert opts[:fed_auth_required] == true
    assert opts[:nonce] == @nonce
  end

  test "decode prelogin response without federated authentication" do
    # VERSION | ENCRYPTION(NOT_SUP) | FEDAUTHREQUIRED(0x00)
    packet =
      <<0x00, 16::unsigned-16, 6::unsigned-16>> <>
        <<0x01, 22::unsigned-16, 1::unsigned-16>> <>
        <<0x06, 23::unsigned-16, 1::unsigned-16>> <>
        <<0xFF>> <>
        <<4, 0, 10, 0, 0, 0>> <> <<0x02>> <> <<0x00>>

    s = %Tds.Protocol{opts: [ssl: :not_supported]}

    assert {:login, %{opts: opts}} = Prelogin.decode(packet, s)
    assert opts[:fed_auth_required] == false
    assert is_nil(opts[:nonce])
  end
end
