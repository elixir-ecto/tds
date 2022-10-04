defmodule Tds.Parameter do
  @moduledoc false

  alias Tds.Types

  @type t :: %__MODULE__{
          name: String.t() | nil,
          direction: :input | :output,
          value: String.t() | nil,
          type: atom() | nil,
          length: nil | integer
        }

  defstruct name: "",
            direction: :input,
            value: "",
            type: nil,
            length: nil

  def option_flags(%__MODULE__{direction: direction, value: value}) do
    fByRefValue =
      case direction do
        :output -> 1
        _ -> 0
      end

    fDefaultValue =
      case value do
        :default -> 1
        _ -> 0
      end

    <<0::size(6), fDefaultValue::size(1), fByRefValue::size(1)>>
  end

  def prepared_params(params) do
    params
    |> List.wrap()
    |> name(0)
    |> Enum.map_join(", ", fn param ->
      param
      |> fix_data_type()
      |> Types.encode_param_descriptor()
    end)
  end

  @doc """
  Prepares parameters by giving them names, define missing type, encoding value
  if necessary.
  """
  def prepare_params(params) do
    params
    |> List.wrap()
    |> name(0)
    |> Enum.map(&fix_data_type/1)
  end

  def name(params, name) do
    do_name(params, name, [])
  end

  def do_name([param | tail], name, acc) do
    name = name + 1

    param =
      case param do
        %__MODULE__{name: nil} -> fix_data_type(%{param | name: "@#{name}"})
        %__MODULE__{} -> fix_data_type(param)
        raw_param -> fix_data_type(raw_param, name)
      end

    do_name(tail, name, [param | acc])
  end

  def do_name([], _, acc) do
    acc
  end

  def fix_data_type(%__MODULE__{type: type, value: _value} = param)
      when not is_nil(type) do
    param
  end

  def fix_data_type(%__MODULE__{type: nil, value: nil} = param) do
    # should fix ecto has_one, on_change :nulify issue where type is not know when ecto
    # build query/statement for on_chage callback
    %{param | type: :binary}
  end

  def fix_data_type(%__MODULE__{value: value} = param)
      when is_boolean(value) do
    %{param | type: :boolean}
  end

  def fix_data_type(%__MODULE__{value: value} = param)
      when is_binary(value) and value == "" do
    %{param | type: :string}
  end

  def fix_data_type(%__MODULE__{value: value} = param)
      when is_binary(value) do
    if String.valid?(value) do
      %{param | type: :string}
    else
      %{param | type: :binary}
    end
  end

  def fix_data_type(%__MODULE__{value: value} = param)
      when is_integer(value) do
    # if -2_147_483_648 >= value and value <= 2_147_483_647 do
    #   %{param | type: :integer}
    # else
    #   %{param | type: :bigint}
    # end
    %{param | type: :integer}
  end

  def fix_data_type(%__MODULE__{value: value} = param)
      when is_float(value) do
    %{param | type: :float}
  end

  def fix_data_type(%__MODULE__{value: %Decimal{}} = param) do
    %{param | type: :decimal}
  end

  def fix_data_type(%__MODULE__{value: {{_, _, _}}} = param) do
    %{param | type: :date}
  end

  def fix_data_type(%__MODULE__{value: %Date{}} = param) do
    %{param | type: :date}
  end

  def fix_data_type(%__MODULE__{value: {{_, _, _, _}}} = param) do
    %{param | type: :time}
  end

  def fix_data_type(%__MODULE__{value: %Time{}} = param) do
    %{param | type: :time}
  end

  def fix_data_type(%__MODULE__{value: {{_, _, _}, {_, _, _}}} = param) do
    %{param | type: :datetime}
  end

  def fix_data_type(%__MODULE__{value: %NaiveDateTime{microsecond: {_, s}}} = param) do
    type = if s > 3, do: :datetime2, else: :datetime
    %{param | type: type}
  end

  def fix_data_type(%__MODULE__{value: {{_, _, _}, {_, _, _, fsec}}} = param) do
    # todo: enable warning and introduce Tds.Types.DateTime2 and Tds.Types.DateTime
    # Logger.warn(fn -> "Datetime as tuple is obsolete, please use NaiveDateTime." end)
    type = if rem(fsec, 1000) > 0, do: :datetime2, else: :datetime
    %{param | type: type}
  end

  def fix_data_type(%__MODULE__{value: %DateTime{}} = param) do
    %{param | type: :datetimeoffset}
  end

  def fix_data_type(%__MODULE__{value: {{_y, _m, _d}, _time, _offset}} = param) do
    %{param | type: :datetimeoffset}
  end

  def fix_data_type(%__MODULE__{} = raw_param, acc) do
    param =
      if is_nil(raw_param.name) do
        %{raw_param | name: "@#{acc}"}
      else
        raw_param
      end

    fix_data_type(param)
  end

  def fix_data_type(raw_param, acc) do
    __MODULE__
    |> struct!(name: "@#{acc}", value: raw_param)
    |> fix_data_type()
  end
end
