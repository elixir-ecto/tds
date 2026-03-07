defmodule Tds.Parameter do
  @moduledoc false

  alias Tds.Type.Registry

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

  def prepared_params(params, registry \\ nil) do
    reg = registry || default_registry()

    params
    |> List.wrap()
    |> name(0)
    |> Enum.map_join(", ", fn param ->
      param_descriptor(param, reg)
    end)
  end

  @doc """
  Prepares parameters by giving them names, define missing type,
  encoding value if necessary.
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
        %__MODULE__{name: nil} ->
          fix_data_type(%{param | name: "@#{name}"})

        %__MODULE__{} ->
          fix_data_type(param)

        raw_param ->
          fix_data_type(raw_param, name)
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

  def fix_data_type(
        %__MODULE__{value: %NaiveDateTime{microsecond: {_, s}}} =
          param
      ) do
    type = if s > 3, do: :datetime2, else: :datetime
    %{param | type: type}
  end

  def fix_data_type(%__MODULE__{value: {{_, _, _}, {_, _, _, fsec}}} = param) do
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
    fix_data_type(%__MODULE__{name: "@#{acc}", value: raw_param})
  end

  @doc """
  Generates a SQL parameter descriptor for a single parameter.

  Returns a string like `"@name int"` or `"@name nvarchar(2000)"`.
  """
  def encode_param_descriptor(%__MODULE__{} = param) do
    param_descriptor(param, default_registry())
  end

  defp param_descriptor(
         %__MODULE__{name: name, type: type, value: value},
         registry
       )
       when not is_nil(type) do
    handler = resolve_handler(registry, type)
    meta = infer_metadata(handler, value, type)
    desc = handler.param_descriptor(value, meta)
    "#{name} #{desc}"
  end

  defp param_descriptor(%__MODULE__{} = param, registry) do
    param
    |> fix_data_type()
    |> param_descriptor(registry)
  end

  defp resolve_handler(registry, type) do
    case Registry.handler_for_name(registry, type) do
      {:ok, handler} ->
        handler

      :error ->
        {:ok, handler} =
          Registry.handler_for_name(registry, :string)

        handler
    end
  end

  defp infer_metadata(handler, value, type) do
    case handler.infer(value) do
      {:ok, meta} -> Map.put(meta, :type, type)
      :skip -> %{type: type}
    end
  end

  defp default_registry do
    Registry.new()
  end
end
