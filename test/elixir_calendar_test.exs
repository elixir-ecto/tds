defmodule ElixirCalendarTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Types
  alias Tds.Parameter

  setup do
    {:ok, pid} =
      :tds
      |> Application.fetch_env!(:opts)
      |> Keyword.put(:use_elixir_calendar_types, true)
      |> Tds.start_link()

    # required for direct encoder/decoder testing
    Tds.Utils.use_elixir_calendar_types(true)
    {:ok, [pid: pid]}
  end

  test "Elixir.Time type", context do
    times = [
      ~T[20:26:51.123000],
      ~T[20:26:51],
      ~T[20:26:51.0],
      ~T[20:26:51.000000],
      ~T[20:26:51.000001],
      ~T[20:26:51.00001],
      ~T[20:26:51.0001],
      ~T[20:26:51.001],
      ~T[20:26:51.01],
      ~T[20:26:51.1],
      ~T[20:26:51.12],
      ~T[20:26:51.123],
      ~T[20:26:51.1234],
      ~T[20:26:51.12345]
    ]

    Enum.each(times, fn t ->
      {time, scale} = Types.encode_time(t)
      assert t == Types.decode_time(scale, time)

      assert [[^t]] =
        query("SELECT @1", [
          %Parameter{
            name: "@1",
            value: t
          }
        ])
    end)
  end
end
