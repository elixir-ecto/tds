defmodule ElixirCalendarTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  alias Tds.Types
  alias Tds.Parameter, as: P

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
      assert [[^t]] = query("SELECT @1", [%P{name: "@1", value: t}])
    end)
  end

  test "Elixir.Date type to SQL Date", context do
    # AD dates are not supported yet since `:calendar.date_to_georgian_days` do not
    # support negative years
    date = ~D[0002-02-28]
    assert date == Types.encode_date(date) |> Types.decode_date()
    assert [[date]] == query("select @1", [%P{name: "@1", value: date}])

    date = ~D[2020-02-28]
    assert date == Types.encode_date(date) |> Types.decode_date()
    assert [[date]] == query("select @1", [%P{name: "@1", value: date}])
  end

  test "Elixir.NaiveDateTime type", context do
    # sql server datetime precision is not exacly 3 decimals precise, value is rader
    # round up to nearest .000, .003, .007. In case of near midnigh day is incremented
    # (e.g. 2020-02-28 23:59:59.999 will increment day 2020-02-29 00:00:00.000)

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
      {~N[2020-02-28 23:59:59.999], ~N[2020-02-29 00:00:00.000]}
    ]

    Enum.each(datetimes, fn {dt_in, dt_out} ->
      token = Types.encode_datetime(dt_in)
      assert dt_out == Types.decode_datetime(token)

      assert [[^dt_out]] =
               query("SELECT @1", [
                 %P{name: "@1", value: dt_in, type: :datetime}
               ])
    end)
    type = :datetime
    datetime2s = [
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.000000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.00000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.0000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.00], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.0], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.1], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.01], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.001], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.0001], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.00001], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.000001], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.100000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.10000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.1000], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.100], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.10], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.1], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.12], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.123], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.1234], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.12345], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:51.123456], type: type},
      %P{name: "@1", value: ~N[2020-02-28 23:59:59.999999], type: type},
    ]

    Enum.each(datetime2s, fn %{value: dt} = p ->
      {token, scale} = Types.encode_datetime2(dt)
      assert dt == Types.decode_datetime2(scale, token)
      assert [[^dt]] = query("SELECT @1", [p])
    end)
  end

  test "Elixir.DateTime to SQL DateTimeOffset", context do
    type = :datetimeoffset
    dts = [
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.000000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.00000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.0000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.00Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.0Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.1Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.10Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.100Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.1000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.10000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.100000Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.12Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.123Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.1234Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.12345Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.123456Z], type: type},
      %P{name: "@1", value: ~U[2020-02-28 23:59:59.999999Z], type: type},
    ]

    Enum.each(dts, fn %{value: dt, microsecond: {_, s}} = p ->
      {token, scale} = Types.encode_datetimeoffset(dt, s)
      assert dt == Types.decode_datetimeoffset(scale, token)
      assert [[^dt]] = query("SELECT @1", [p])
    end)

  end
end
