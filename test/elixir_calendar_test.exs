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

  test "Elixir.NaiveDateTime type", context do
    # Precision is not exacly to 3 decimals, they are rader round to neares
    # .000, .003, .007 plus day is incremented if round causes midnight case
    datetimes = [
      {~N[2020-02-28 23:59:51.000], ~N[2020-02-28 23:59:51.000]},
      {~N[2020-02-28 23:59:51.003], ~N[2020-02-28 23:59:51.003]},
      {~N[2020-02-28 23:59:51.005], ~N[2020-02-28 23:59:51.007]},
      {~N[2020-02-28 23:59:51.007], ~N[2020-02-28 23:59:51.007]},
      {~N[2020-02-28 23:59:51.008], ~N[2020-02-28 23:59:51.007]},
      {~N[2020-02-28 23:59:51.009], ~N[2020-02-28 23:59:51.010]},
      {~N[2020-02-28 23:59:51.010], ~N[2020-02-28 23:59:51.010]},
      {~N[2020-02-28 23:59:51.013], ~N[2020-02-28 23:59:51.013]},
      {~N[2020-02-28 23:59:51.017], ~N[2020-02-28 23:59:51.017]},
      {~N[2020-02-28 23:59:51.020], ~N[2020-02-28 23:59:51.020]},
      {~N[2020-02-28 23:59:51.100], ~N[2020-02-28 23:59:51.100]},
      {~N[2020-02-28 23:59:51.120], ~N[2020-02-28 23:59:51.120]},
      {~N[2020-02-28 23:59:51.123], ~N[2020-02-28 23:59:51.123]},
      {~N[2020-02-28 23:59:51.997], ~N[2020-02-28 23:59:51.997]},
      # midnight case, should increment day too
      {~N[2020-02-28 23:59:59.999], ~N[2020-02-29 00:00:00.000]},
    ]

    # here we are testing datetime and datetime2
    # (depends on what is the microsecond precision)
    Enum.each(datetimes, fn {dt_in, dt_out} ->
      # r = query("SELECT CONVERT(varchar(100), @1, 127)", [
      assert [[^dt_out]] =
        query("SELECT @1", [
          %Parameter{
            name: "@1",
            value: dt_in
          }
        ])
    end)
  end
end
