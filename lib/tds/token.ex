defmodule Tds.Token do
  @moduledoc """
  """
  import Tds.Protocol.Grammar
  import Bitwise
  alias Tds.Token.{
    AltMetadata,
    AltRow,
    ColMetadata,
    ColInfo,
    Done,
    DoneProc,
    DoneInProc,
    EnvChange,
    Error,
    FeatureExtAck,
    FedAuthInfo,
    Info,
    LoginAck,
    NBCRow,
    Offset,
    Order,
    ReturnStatus,
    ReturnValue,
    Row,
    SSPI,
    TabName
  }

  def decode(<<token::byte(), rest::binary>>, col_metadata \\ []) do
    case token do
      0x88 -> AltMetadata.decode(rest, col_metadata)
      0xD3 -> AltRow.decode(rest, col_metadata)
      0x81 -> ColMetadata.decode(rest, col_metadata)
      0xA5 -> ColInfo.decode(rest, col_metadata)
      0xFD -> Done.decode(rest, col_metadata)
      0xFE -> DoneProc.decode(rest, col_metadata)
      0xFF -> DoneInProc.decode(rest, col_metadata)
      0xE3 -> EnvChange.decode(rest, col_metadata)
      0xAA -> Error.decode(rest, col_metadata)
      0xAE -> FeatureExtAck.decode(rest, col_metadata)
      0xEE -> FedAuthInfo.decode(rest, col_metadata)
      0xAB -> Info.decode(rest, col_metadata)
      0xAD -> LoginAck.decode(rest, col_metadata)
      0xD2 -> NBCRow.decode(rest, col_metadata)
      0x78 -> Offset.decode(rest, col_metadata)
      0xA9 -> Order.decode(rest, col_metadata)
      0x79 -> ReturnStatus.decode(rest, col_metadata)
      0xAC -> ReturnValue.decode(rest, col_metadata)
      0xD1 -> Row.decode(rest, col_metadata)
      0xED -> SSPI.decode(rest, col_metadata)
      0xA4 -> TabName.decode(rest, col_metadata)
      _ -> raise(Tds.Error, "Unrecognized token #{inspect(token, base: 16)}")
    end
  end

  def class(token) when token > 0 and token <= 0xFF do
    case token &&& 0b00110000 do
      0b0000_0000 -> {:variable, :count}
      0b0010_0000 -> {:variable, :length}
      0b0001_0000 -> {:fixed, 0}
      0b0011_0000 -> {:fixed, fixed_length(token)}
    end
  end

  defp fixed_length(token) do
    case token &&& 0b00001100 do
      0b0000_0000 -> 1
      0b0000_0100 -> 2
      0b0000_1000 -> 4
      0b0000_1100 -> 8
    end
  end
end
