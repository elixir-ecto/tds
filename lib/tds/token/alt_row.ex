defmodule Tds.Token.AltRow do
  import Tds.Protocol.Grammar

  def decode(<<_count::little-ushort(), _rest::binary>>, _col_metadata) do
    raise "Not supported"
  end
end
