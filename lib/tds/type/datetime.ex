defmodule Tds.Type.DateTime do
  @moduledoc """
  TDS type handler for date and time values.

  Handles seven type codes on decode:
    - daten (0x28) — Date
    - timen (0x29) — Time with scale
    - datetime2n (0x2A) — NaiveDateTime with scale
    - datetimeoffsetn (0x2B) — DateTime with timezone offset
    - smalldatetime (0x3A) — 4-byte NaiveDateTime (minute precision)
    - datetime (0x3D) — 8-byte NaiveDateTime (1/300s precision)
    - datetimen (0x6F) — nullable smalldatetime/datetime

  Always returns Elixir calendar structs: Date, Time,
  NaiveDateTime, or DateTime. No tuple format.

  Encodes Date as daten, Time as timen, NaiveDateTime as
  datetime2n, and DateTime as datetimeoffsetn.
  """

  @behaviour Tds.Type

  import Tds.Protocol.Constants

  @year_1900_days :calendar.date_to_gregorian_days({1900, 1, 1})
  @secs_in_min 60
  @secs_in_hour 60 * @secs_in_min
  @max_time_scale 7

  @daten_code tds_type(:daten)
  @timen_code tds_type(:timen)
  @datetime2n_code tds_type(:datetime2n)
  @datetimeoffsetn_code tds_type(:datetimeoffsetn)
  @smalldatetime_code tds_type(:smalldatetime)
  @datetime_code tds_type(:datetime)
  @datetimen_code tds_type(:datetimen)

  # -- type_codes / type_names -----------------------------------------

  @impl true
  def type_codes do
    [
      @daten_code,
      @timen_code,
      @datetime2n_code,
      @datetimeoffsetn_code,
      @smalldatetime_code,
      @datetime_code,
      @datetimen_code
    ]
  end

  @impl true
  def type_names do
    [:date, :time, :datetime, :datetime2, :smalldatetime, :datetimeoffset]
  end

  # -- decode_metadata -------------------------------------------------

  @impl true
  def decode_metadata(<<@daten_code, rest::binary>>) do
    {:ok, %{data_reader: :bytelen, type_code: @daten_code}, rest}
  end

  def decode_metadata(
        <<@timen_code, scale::unsigned-8, rest::binary>>
      ) do
    meta = %{
      data_reader: :bytelen,
      scale: scale,
      type_code: @timen_code
    }

    {:ok, meta, rest}
  end

  def decode_metadata(
        <<@datetime2n_code, scale::unsigned-8, rest::binary>>
      ) do
    meta = %{
      data_reader: :bytelen,
      scale: scale,
      type_code: @datetime2n_code
    }

    {:ok, meta, rest}
  end

  def decode_metadata(
        <<@datetimeoffsetn_code, scale::unsigned-8,
          rest::binary>>
      ) do
    meta = %{
      data_reader: :bytelen,
      scale: scale,
      type_code: @datetimeoffsetn_code
    }

    {:ok, meta, rest}
  end

  def decode_metadata(<<@smalldatetime_code, rest::binary>>) do
    meta = %{
      data_reader: {:fixed, 4},
      type_code: @smalldatetime_code
    }

    {:ok, meta, rest}
  end

  def decode_metadata(<<@datetime_code, rest::binary>>) do
    meta = %{
      data_reader: {:fixed, 8},
      type_code: @datetime_code
    }

    {:ok, meta, rest}
  end

  def decode_metadata(
        <<@datetimen_code, length::unsigned-8, rest::binary>>
      ) do
    meta = %{
      data_reader: :bytelen,
      length: length,
      type_code: @datetimen_code
    }

    {:ok, meta, rest}
  end

  # -- decode ----------------------------------------------------------

  @impl true
  def decode(nil, _metadata), do: nil

  def decode(data, %{type_code: @daten_code}),
    do: decode_date(data)

  def decode(data, %{type_code: @timen_code} = m),
    do: decode_time(m.scale, data)

  def decode(data, %{type_code: @smalldatetime_code}),
    do: decode_smalldatetime(data)

  def decode(data, %{type_code: @datetime_code}),
    do: decode_datetime(data)

  def decode(data, %{type_code: @datetimen_code, length: 4}),
    do: decode_smalldatetime(data)

  def decode(data, %{type_code: @datetimen_code, length: 8}),
    do: decode_datetime(data)

  def decode(data, %{type_code: @datetime2n_code} = m),
    do: decode_datetime2(m.scale, data)

  def decode(data, %{type_code: @datetimeoffsetn_code} = m),
    do: decode_datetimeoffset(m.scale, data)

  # -- encode ----------------------------------------------------------

  @impl true
  def encode(nil, %{type: :date}) do
    {tds_type(:daten), <<tds_type(:daten)>>, <<0x00>>}
  end

  def encode(%Date{} = date, %{type: :date}) do
    data = encode_date(date)
    {tds_type(:daten), <<tds_type(:daten)>>, [<<0x03>>, data]}
  end

  def encode(nil, %{type: :time}) do
    type = tds_type(:timen)
    {type, <<type, @max_time_scale>>, <<0x00>>}
  end

  def encode(%Time{} = time, %{type: :time}) do
    type = tds_type(:timen)
    {data, scale} = encode_time(time)
    len = time_byte_length(scale)
    {type, <<type, scale>>, [<<len>>, data]}
  end

  def encode(nil, %{type: :datetime2}) do
    type = tds_type(:datetime2n)
    {type, <<type, @max_time_scale>>, <<0x00>>}
  end

  def encode(%NaiveDateTime{} = ndt, %{type: :datetime2}) do
    type = tds_type(:datetime2n)
    {data, scale} = encode_datetime2(ndt)
    len = time_byte_length(scale) + 3
    {type, <<type, scale>>, [<<len>>, data]}
  end

  def encode(nil, %{type: :datetimeoffset}) do
    type = tds_type(:datetimeoffsetn)
    {type, <<type, @max_time_scale>>, <<0x00>>}
  end

  def encode(%DateTime{} = dt, %{type: :datetimeoffset}) do
    type = tds_type(:datetimeoffsetn)
    {_, scale} = dt.microsecond
    data = encode_datetimeoffset(dt, scale)
    len = time_byte_length(scale) + 3 + 2
    {type, <<type, scale>>, [<<len>>, data]}
  end

  # Legacy datetime (8-byte datetimen)
  def encode(nil, %{type: :datetime}) do
    type = tds_type(:datetimen)
    {type, <<type, 0x08>>, <<0x00>>}
  end

  def encode(value, %{type: :datetime}) do
    ndt = to_naive_datetime(value)
    type = tds_type(:datetimen)
    data = encode_legacy_datetime(ndt)
    {type, <<type, 0x08>>, [<<0x08>>, data]}
  end

  # Legacy smalldatetime (4-byte datetimen)
  def encode(nil, %{type: :smalldatetime}) do
    type = tds_type(:datetimen)
    {type, <<type, 0x04>>, <<0x00>>}
  end

  def encode(value, %{type: :smalldatetime}) do
    ndt = to_naive_datetime(value)
    type = tds_type(:datetimen)
    data = encode_smalldatetime(ndt)
    {type, <<type, 0x04>>, [<<0x04>>, data]}
  end

  # Tuple format: {y,m,d}
  def encode({_, _, _} = date_tuple, %{type: :date} = meta) do
    encode(Date.from_erl!(date_tuple), meta)
  end

  # Tuple format: {h,m,s} -> default scale 7
  def encode({h, m, s}, %{type: :time}) do
    encode_time_tuple({h, m, s, 0}, @max_time_scale)
  end

  # Tuple format: {h,m,s,fsec} -> scale 7 (100ns units)
  def encode({h, m, s, fsec}, %{type: :time}) do
    encode_time_tuple({h, m, s, fsec}, @max_time_scale)
  end

  # Tuple format: {{y,m,d},{h,m,s}} or {{y,m,d},{h,m,s,fsec}}
  def encode({date, time}, %{type: :datetime2})
      when is_tuple(date) do
    encode_dt2_tuple(date, time, @max_time_scale)
  end

  # Tuple format: {{y,m,d},{h,m,s|{h,m,s,us}},offset_min}
  # Replicates old Tds.Types behavior: sends time/date as-is
  # with the offset appended, no UTC conversion.
  def encode(
        {{_, _, _} = d, time, offset_min},
        %{type: :datetimeoffset}
      ) do
    type = tds_type(:datetimeoffsetn)
    time_tuple = normalize_time_tuple(time)
    {time_bin, scale} = encode_time_raw(time_tuple, @max_time_scale)
    date_bin = encode_date(Date.from_erl!(d))
    data = time_bin <> date_bin <> <<offset_min::little-signed-16>>
    len = time_byte_length(scale) + 3 + 2
    {type, <<type, scale>>, [<<len>>, data]}
  end

  # -- param_descriptor ------------------------------------------------

  @impl true
  def param_descriptor(_value, %{type: :date}), do: "date"

  def param_descriptor(%Time{microsecond: {_, s}}, %{type: :time}),
    do: "time(#{s})"

  def param_descriptor(_value, %{type: :time}), do: "time"

  def param_descriptor(_value, %{type: :datetime}), do: "datetime"

  def param_descriptor(_value, %{type: :smalldatetime}),
    do: "smalldatetime"

  def param_descriptor(
        %NaiveDateTime{microsecond: {_, s}},
        %{type: :datetime2}
      ),
      do: "datetime2(#{s})"

  def param_descriptor(_value, %{type: :datetime2}), do: "datetime2"

  def param_descriptor(
        %DateTime{microsecond: {_, s}},
        %{type: :datetimeoffset}
      ),
      do: "datetimeoffset(#{s})"

  def param_descriptor(_value, %{type: :datetimeoffset}),
    do: "datetimeoffset"

  # -- infer -----------------------------------------------------------

  @impl true
  def infer(%Date{}), do: {:ok, %{type: :date}}
  def infer(%Time{}), do: {:ok, %{type: :time}}
  def infer(%NaiveDateTime{}), do: {:ok, %{type: :datetime2}}
  def infer(%DateTime{}), do: {:ok, %{type: :datetimeoffset}}
  def infer(_value), do: :skip

  # -- private: tuple encoding -----------------------------------------

  defp encode_time_tuple(time_tuple, scale) do
    type = tds_type(:timen)
    {data, scale} = encode_time_raw(time_tuple, scale)
    len = time_byte_length(scale)
    {type, <<type, scale>>, [<<len>>, data]}
  end

  defp encode_dt2_tuple(date, time, scale) do
    type = tds_type(:datetime2n)
    time_tuple = normalize_time_tuple(time)
    {time_bin, scale} = encode_time_raw(time_tuple, scale)
    date_bin = encode_date(Date.from_erl!(date))
    len = time_byte_length(scale) + 3
    {type, <<type, scale>>, [<<len>>, time_bin <> date_bin]}
  end

  defp normalize_time_tuple({h, m, s}), do: {h, m, s, 0}
  defp normalize_time_tuple({_, _, _, _} = t), do: t

  # Convert NaiveDateTime to tuple format for legacy datetime
  defp to_naive_datetime(%NaiveDateTime{} = ndt), do: ndt

  defp to_naive_datetime({{y, m, d}, {h, mi, s}}) do
    NaiveDateTime.from_erl!({{y, m, d}, {h, mi, s}})
  end

  defp to_naive_datetime({{y, m, d}, {h, mi, s, us}})
       when us < 1_000_000 do
    NaiveDateTime.from_erl!(
      {{y, m, d}, {h, mi, s}},
      {us, 6}
    )
  end

  # fsec >= 1_000_000 means 100ns units (scale 7), convert
  defp to_naive_datetime({{y, m, d}, {h, mi, s, fsec}}) do
    us = div(fsec, 10)

    NaiveDateTime.from_erl!(
      {{y, m, d}, {h, mi, s}},
      {us, 6}
    )
  end

  # -- private: date ---------------------------------------------------

  defp decode_date(<<days::little-24>>) do
    date = :calendar.gregorian_days_to_date(days + 366)
    Date.from_erl!(date, Calendar.ISO)
  end

  defp encode_date(%Date{} = date) do
    days =
      date
      |> Date.to_erl()
      |> :calendar.date_to_gregorian_days()
      |> Kernel.-(366)

    <<days::little-24>>
  end

  # -- private: smalldatetime ------------------------------------------

  defp decode_smalldatetime(
         <<days::little-unsigned-16, mins::little-unsigned-16>>
       ) do
    date = :calendar.gregorian_days_to_date(@year_1900_days + days)
    hour = div(mins, 60)
    min = mins - hour * 60
    NaiveDateTime.from_erl!({date, {hour, min, 0}})
  end

  defp encode_smalldatetime(%NaiveDateTime{} = ndt) do
    {date, {hour, min, _}} = NaiveDateTime.to_erl(ndt)
    days = :calendar.date_to_gregorian_days(date) - @year_1900_days
    mins = hour * 60 + min
    <<days::little-unsigned-16, mins::little-unsigned-16>>
  end

  # -- private: datetime -----------------------------------------------

  defp decode_datetime(
         <<days::little-signed-32, secs300::little-unsigned-32>>
       ) do
    date = :calendar.gregorian_days_to_date(@year_1900_days + days)
    milliseconds = round(secs300 * 10 / 3)
    usec = rem(milliseconds, 1_000)
    seconds = div(milliseconds, 1_000)
    {_, {h, m, s}} = :calendar.seconds_to_daystime(seconds)

    NaiveDateTime.from_erl!(
      {date, {h, m, s}},
      {usec * 1_000, 3},
      Calendar.ISO
    )
  end

  defp encode_legacy_datetime(%NaiveDateTime{} = ndt) do
    {date, {h, m, s}} = NaiveDateTime.to_erl(ndt)
    {us, _} = ndt.microsecond
    days = :calendar.date_to_gregorian_days(date) - @year_1900_days
    milliseconds = ((h * 60 + m) * 60 + s) * 1_000 + us / 1_000
    secs_300 = round(milliseconds / (10 / 3))

    {days, secs_300} =
      if secs_300 == 25_920_000 do
        {days + 1, 0}
      else
        {days, secs_300}
      end

    <<days::little-signed-32, secs_300::little-unsigned-32>>
  end

  # -- private: time ---------------------------------------------------

  defp decode_time(scale, fsec_bin) do
    parsed_fsec = parse_time_fsec(scale, fsec_bin)
    fs_per_sec = trunc(:math.pow(10, scale))

    hour = trunc(parsed_fsec / fs_per_sec / @secs_in_hour)
    rem1 = parsed_fsec - hour * @secs_in_hour * fs_per_sec

    min = trunc(rem1 / fs_per_sec / @secs_in_min)
    rem2 = rem1 - min * @secs_in_min * fs_per_sec

    sec = trunc(rem2 / fs_per_sec)
    frac = trunc(rem2 - sec * fs_per_sec)

    {usec, out_scale} = fsec_to_microsecond(frac, scale)
    Time.from_erl!({hour, min, sec}, {usec, out_scale})
  end

  defp parse_time_fsec(scale, bin) when scale in [0, 1, 2] do
    <<val::little-unsigned-24>> = bin
    val
  end

  defp parse_time_fsec(scale, bin) when scale in [3, 4] do
    <<val::little-unsigned-32>> = bin
    val
  end

  defp parse_time_fsec(scale, bin) when scale in [5, 6, 7] do
    <<val::little-unsigned-40>> = bin
    val
  end

  defp fsec_to_microsecond(frac, scale) when scale > 6 do
    {trunc(frac / 10), 6}
  end

  defp fsec_to_microsecond(frac, scale) do
    {trunc(frac * :math.pow(10, 6 - scale)), scale}
  end

  defp encode_time(%Time{} = t) do
    {h, m, s} = Time.to_erl(t)
    {_, scale} = t.microsecond
    fsec = microsecond_to_fsec(t.microsecond)
    encode_time_raw({h, m, s, fsec}, scale)
  end

  defp encode_time_raw({hour, min, sec, fsec}, scale) do
    fs_per_sec = trunc(:math.pow(10, scale))

    total =
      hour * 3600 * fs_per_sec +
        min * 60 * fs_per_sec +
        sec * fs_per_sec +
        fsec

    bin =
      cond do
        scale < 3 -> <<total::little-unsigned-24>>
        scale < 5 -> <<total::little-unsigned-32>>
        true -> <<total::little-unsigned-40>>
      end

    {bin, scale}
  end

  defp microsecond_to_fsec({us, 6}), do: us

  defp microsecond_to_fsec({us, scale}),
    do: trunc(us / :math.pow(10, 6 - scale))

  # -- private: datetime2 ----------------------------------------------

  defp decode_datetime2(scale, data) do
    tlen = time_byte_length(scale)
    <<time_bin::binary-size(tlen), date_bin::binary-3>> = data
    date = decode_date(date_bin)
    time = decode_time(scale, time_bin)
    NaiveDateTime.new!(date, time)
  end

  defp encode_datetime2(%NaiveDateTime{} = value) do
    t = NaiveDateTime.to_time(value)
    {time_bin, scale} = encode_time(t)
    date_bin = encode_date(NaiveDateTime.to_date(value))
    {time_bin <> date_bin, scale}
  end

  # -- private: datetimeoffset -----------------------------------------

  defp decode_datetimeoffset(scale, data) do
    tlen = time_byte_length(scale)
    dt2_len = tlen + 3

    <<dt2_bin::binary-size(dt2_len),
      _offset_min::little-signed-16>> = data

    # Wire stores UTC time + offset. Return UTC DateTime
    # (same as old Tds.Types behavior) so roundtrip is stable.
    naive_utc = decode_datetime2(scale, dt2_bin)
    DateTime.from_naive!(naive_utc, "Etc/UTC")
  end

  defp encode_datetimeoffset(%DateTime{utc_offset: offset} = dt, scale) do
    {dt2_bin, _} =
      dt
      |> DateTime.add(-offset)
      |> DateTime.to_naive()
      |> encode_ndt_with_scale(scale)

    offset_min = div(offset, 60)
    dt2_bin <> <<offset_min::little-signed-16>>
  end

  defp encode_ndt_with_scale(%NaiveDateTime{} = ndt, scale) do
    {h, m, s} = NaiveDateTime.to_erl(ndt) |> elem(1)
    fsec = microsecond_to_fsec(ndt.microsecond)
    {time_bin, scale} = encode_time_raw({h, m, s, fsec}, scale)
    date_bin = encode_date(NaiveDateTime.to_date(ndt))
    {time_bin <> date_bin, scale}
  end
end
