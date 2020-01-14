defmodule Tds.Encoding do
  use Rustler, otp_app: :tds, crate: "tds_encoding"

  # When your NIF is loaded, it will override this function.
  def encode(_str, _encoding), do: error()
  def decode(_str, _encoding), do: error()

  def error(), do: :erlang.nif_error(:nif_not_loaded)
end
