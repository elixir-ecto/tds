defmodule Tds.Error do
  defexception [:message, :mssql]

  def message(e) do
    if kw = e.mssql do
      msg = "#{kw[:severity]} (#{kw[:code]}): #{kw[:message]}"
    end

    msg || e.message
  end
end
