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

  @type domain :: String.t()
  @type username :: String.t()
  @type password :: String.t()
  @type negotiation_option :: {:domain, domain()} | {:workstation, String.t()}
  @type negotiation_options :: [negotiation_option()]

  @doc """
  Builds NTLM negotiation message `<<"NTLMSSP", 0x00, 0x01 ...>>`

  - `opts` - is a `Keyword.t` list that requires `:domain` key and accepts
  optinal `:workstation` string. Both values can only contain valid ASCII
  characters
  """
  @spec negotiate(negotiation_options) :: binary()
  def negotiate(negotiation_options) do
    fixed_data_len = 40

    domain =
      :unicode.characters_to_binary(
        negotiation_options[:domain],
        :unicode,
        :latin1
      )

    domain_length = String.length(negotiation_options[:domain])

    workstation =
      negotiation_options
      |> Keyword.get(:workstation)
      |> Kernel.||("")

    workstation_length = String.length(workstation)
    workstation = :unicode.characters_to_binary(workstation, :unicode, :latin1)

    type1_flags = type1_flags(workstation != <<>>)

    <<
      "NTLMSSP",
      0x00,
      0x01::little-unsigned-32,
      type1_flags::little-unsigned-32,
      domain_length::little-unsigned-16,
      domain_length::little-unsigned-16,
      fixed_data_len + workstation_length::little-unsigned-32,
      workstation_length::little-unsigned-16,
      workstation_length::little-unsigned-16,
      fixed_data_len::little-unsigned-32,
      5,
      0,
      2195::little-unsigned-16,
      0,
      0,
      0,
      15,
      domain::binary-size(domain_length)-unit(8),
      workstation::binary-size(workstation_length)-unit(8)
    >>
  end

  @spec authenticate(domain(), username(), password(), binary(), binary()) ::
          binary()
  def authenticate(domain, username, password, server_data, server_nonce) do
    domain = ucs2(domain)
    domain_len = byte_size(domain)
    username = ucs2(username)
    username_len = byte_size(username)
    lmv2_len = 24
    ntlmv2_len = 16
    base_idx = 64
    dn_idx = base_idx
    un_idx = dn_idx + domain_len
    l2_idx = un_idx + username_len * 2
    nt_idx = l2_idx + lmv2_len
    client_nonce = client_nonce()

    {:ok, gen_time} =
      NaiveDateTime.utc_now()
      |> DateTime.from_naive("Etc/UTC")

    gen_time = DateTime.to_unix(gen_time)

    fixed =
      <<"NTLMSSP", 0, 0x03::little-unsigned-32, lmv2_len::little-unsigned-16,
        l2_idx::little-unsigned-32, ntlmv2_len::little-unsigned-16,
        ntlmv2_len::little-unsigned-16, nt_idx::little-unsigned-32,
        domain_len::little-unsigned-16, domain_len::little-unsigned-16,
        dn_idx::little-unsigned-32, username_len::little-unsigned-16,
        username_len::little-unsigned-16, un_idx::little-unsigned-32,
        0x00::little-unsigned-16, 0x00::little-unsigned-16,
        base_idx::little-unsigned-32, 0x00::little-unsigned-16,
        0x00::little-unsigned-16, base_idx::little-unsigned-32,
        0x8201::little-unsigned-16, 0x00::little-unsigned-16>>

    [
      fixed,
      domain,
      username,
      lvm2_response(domain, username, password, server_nonce, client_nonce),
      ntlmv2_response(
        domain,
        username,
        password,
        server_nonce,
        server_data,
        client_nonce,
        gen_time
      ),
      [0x01, 0x01, 0x00, 0x00],
      as_timestamp(gen_time),
      client_nonce,
      [0x00, 0x00],
      server_data,
      [0x00, 0x00]
    ]
    |> IO.iodata_to_binary()
  end

  defp lvm2_response(domain, username, password, server_nonce, client_nonce) do
    hash = ntv2_hash(domain, username, password)
    data = server_nonce <> client_nonce
    new_hash = hmac_md5(data, hash)
    [new_hash, client_nonce]
  end

  defp ntlmv2_response(
         domain,
         username,
         password,
         server_nonce,
         server_data,
         client_nonce,
         gen_time
       ) do
    timestamp = as_timestamp(gen_time)
    hash = ntv2_hash(domain, username, password)

    data = <<
      server_nonce::binary-64,
      0x0101::little-unsigned-32,
      0x0000::little-unsigned-32,
      timestamp::binary-64,
      client_nonce::binary-64,
      0x0000::unsigned-32,
      server_data::binary
    >>

    hmac_md5(data, hash)
  end

  defp client_nonce() do
    1..8
    |> Enum.map(fn _ -> :rand.uniform(255) end)
    |> IO.iodata_to_binary()
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

  defp as_timestamp(unix) do
    tenth_of_usec = (unix + 11_644_473_600) * 10_000_000
    lo = Bitwise.band(tenth_of_usec, 0xFFFFFFFF)

    hi =
      tenth_of_usec
      |> Bitwise.>>>(32)
      |> Bitwise.band(0xFFFFFFFF)

    <<lo::little-unsigned-32, hi::little-unsigned-32>>
  end

  defp ntv2_hash(domain, user, password) do
    hash = nt_hash(password)
    identity = ucs2(String.upcase(user) <> String.upcase(domain))
    hmac_md5(identity, hash)
  end

  defp nt_hash(text) do
    text = ucs2(text)
    :crypto.hash(:md4, text)
  end

  defp hmac_md5(data, key) do
    :crypto.hmac(:md5, key, data)
  end

  defp ucs2(str) do
    :unicode.characters_to_binary(str, :unicode, {:utf16, :little})
  end
end
