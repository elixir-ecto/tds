defmodule Tds.Error do
  defexception [:message, :mssql]

  def message(e) do
    msg = 
    if kw = e.mssql do
      "#{kw[:line_number]} (#{kw[:number]}): #{kw[:msg_text]}"
    end

    msg || e.message
  end
end
