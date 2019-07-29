defmodule Tds.Perf do
  @moduledoc false

  @millisecond  1000
  @second       @millisecond * 1000
  @minute       @second * 60
  @hour         @minute * 60


  def to_string(misec) do
    cond do
      0.9 < misec / @hour ->
        "#{Float.round(misec / @hour, 2)}h"
      0.9 < misec / @minute ->
        "#{Float.round(misec / @minute, 2)}m"
      0.9 < misec / @second ->
        "#{Float.round(misec / @second, 2)}s"
      0.9 < misec / @millisecond ->
        "#{Float.round(misec / @millisecond, 2)}ms"
      :else ->
        "#{misec}μsec"
    end
  end

  @kbyte 1024
  @mbyte @kbyte * 1024
  @gbyte @mbyte * 1024

  def to_size(len) do
    cond do
      0.1 < len / @gbyte ->
        "#{Float.round(len / @gbyte, 3)}GiB"
      0.1 < len / @mbyte ->
        "#{Float.round(len / @mbyte, 3)}MiB"
      0.1 < len / @kbyte ->
        "#{Float.round(len / @kbyte, 3)}KiB"
      :else ->
        "#{len}bytes"
    end
  end
end
