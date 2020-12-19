defmodule Ntlm do
  @moduledoc """
  This module provides encoders and decoders for NTLM
  negotiation and authentincation
  """
  require Bitwise

  @ntlm_NegotiateUnicode 0x00000001
  @ntlm_NegotiateOEM 0x00000002
  @ntlm_RequestTarget 0x00000004
  @ntlm_Unknown9 0x00000008
  @ntlm_NegotiateSign 0x00000010
  @ntlm_NegotiateSeal 0x00000020
  @ntlm_NegotiateDatagram 0x00000040
  @ntlm_NegotiateLanManagerKey 0x00000080
  @ntlm_Unknown8 0x00000100
  @ntlm_NegotiateNTLM 0x00000200
  @ntlm_NegotiateNTOnly 0x00000400
  @ntlm_Anonymous 0x00000800
  @ntlm_NegotiateOemDomainSupplied 0x00001000
  @ntlm_NegotiateOemWorkstationSupplied 0x00002000
  @ntlm_Unknown6 0x00004000
  @ntlm_NegotiateAlwaysSign 0x00008000
  @ntlm_TargetTypeDomain 0x00010000
  @ntlm_TargetTypeServer 0x00020000
  @ntlm_TargetTypeShare 0x00040000
  @ntlm_NegotiateExtendedSecurity 0x00080000
  @ntlm_NegotiateIdentify 0x00100000
  @ntlm_Unknown5 0x00200000
  @ntlm_RequestNonNTSessionKey 0x00400000
  @ntlm_NegotiateTargetInfo 0x00800000
  @ntlm_Unknown4 0x01000000
  @ntlm_NegotiateVersion 0x02000000
  @ntlm_Unknown3 0x04000000
  @ntlm_Unknown2 0x08000000
  @ntlm_Unknown1 0x10000000
  @ntlm_Negotiate128 0x20000000
  @ntlm_NegotiateKeyExchange 0x40000000
  @ntlm_Negotiate56 0x80000000

  @doc """
  Builds NTLM negotiation message `<<"NTLMSSP", 0x00, 0x01 ...>>`

  - `opts` - is a `Keyword.t` list that requires `:domain` key and accepts
  optinal `:workstation` string. Both values can only contain valid ASCII
  characters
  """
  @spec negotiate(keyword) :: <<_::64, _::_*8>>
  def negotiate(opts \\ []) do
    fixed_data_len = 40
    domain = :unicode.characters_to_binary(opts[:domain], :unicode, :latin1)
    domain_length = String.length(opts[:domain])

    workstation =
      opts
      |> Keyword.get(:workstation)
      |> Kernel.||("")

    workstation_length = String.length(workstation)
    workstation = :unicode.characters_to_binary(workstation, :unicode, :latin1)

    type1_flags = type1_flags(workstation != <<>>)

    <<
      "NTLMSSP",
      0x00,
      0x01::little-unsigned-size(4)-unit(8),
      type1_flags::little-unsigned-size(4)-unit(8),
      domain_length::little-unsigned-size(2)-unit(8),
      domain_length::little-unsigned-size(2)-unit(8),
      fixed_data_len + workstation_length::little-unsigned-size(4)-unit(8),
      workstation_length::little-unsigned-size(2)-unit(8),
      workstation_length::little-unsigned-size(2)-unit(8),
      fixed_data_len::little-unsigned-size(4)-unit(8),
      5,
      0,
      2195::little-unsigned-size(2)-unit(8),
      0,
      0,
      0,
      15,
      domain::binary-size(domain_length)-unit(8),
      workstation::binary-size(workstation_length)-unit(8)
    >>
  end

  def authenticate() do
  end

  defp type1_flags(workstation?) do
    0x00000000
    |> Bitwise.bor(@ntlm_NegotiateUnicode)
    |> Bitwise.bor(@ntlm_NegotiateOEM)
    |> Bitwise.bor(@ntlm_RequestTarget)
    |> Bitwise.bor(@ntlm_Unknown9)
    |> Bitwise.bor(@ntlm_NegotiateSign)
    |> Bitwise.bor(@ntlm_NegotiateSeal)
    |> Bitwise.bor(@ntlm_NegotiateDatagram)
    |> Bitwise.bor(@ntlm_NegotiateLanManagerKey)
    |> Bitwise.bor(@ntlm_Unknown8)
    |> Bitwise.bor(@ntlm_NegotiateNTLM)
    |> Bitwise.bor(@ntlm_NegotiateNTOnly)
    |> Bitwise.bor(@ntlm_Anonymous)
    |> Bitwise.bor(@ntlm_NegotiateOemDomainSupplied)
    |> Bitwise.bor(
      if(workstation?,
        do: @ntlm_NegotiateOemWorkstationSupplied,
        else: 0x00000000
      )
    )
    |> Bitwise.bor(@ntlm_Unknown6)
    |> Bitwise.bor(@ntlm_NegotiateAlwaysSign)
    |> Bitwise.bor(@ntlm_TargetTypeDomain)
    |> Bitwise.bor(@ntlm_TargetTypeServer)
    |> Bitwise.bor(@ntlm_TargetTypeShare)
    |> Bitwise.bor(@ntlm_NegotiateExtendedSecurity)
    |> Bitwise.bor(@ntlm_NegotiateIdentify)
    |> Bitwise.bor(@ntlm_Unknown5)
    |> Bitwise.bor(@ntlm_RequestNonNTSessionKey)
    |> Bitwise.bor(@ntlm_NegotiateTargetInfo)
    |> Bitwise.bor(@ntlm_Unknown4)
    |> Bitwise.bor(@ntlm_NegotiateVersion)
    |> Bitwise.bor(@ntlm_Unknown3)
    |> Bitwise.bor(@ntlm_Unknown2)
    |> Bitwise.bor(@ntlm_Unknown1)
    |> Bitwise.bor(@ntlm_Negotiate128)
    |> Bitwise.bor(@ntlm_NegotiateKeyExchange)
    |> Bitwise.bor(@ntlm_Negotiate56)
  end
end
