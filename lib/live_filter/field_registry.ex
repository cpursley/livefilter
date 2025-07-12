defmodule LiveFilter.FieldRegistry do
  @moduledoc """
  Standardized field configuration for LiveFilter.

  The FieldRegistry provides a way to define and manage field configurations
  in a centralized way. It's completely optional - you can use LiveFilter
  without ever creating a registry.

  ## Benefits

    * Centralized field definitions
    * Type safety and validation
    * Consistent operator defaults
    * UI component hints
    * Support for custom field types via the Field protocol

  ## Example

      defmodule MyApp.FilterFields do
        def registry do
          LiveFilter.FieldRegistry.new()
          |> LiveFilter.FieldRegistry.add_field(:title, :string,
            label: "Title",
            operators: [:contains, :equals, :starts_with],
            placeholder: "Search titles..."
          )
          |> LiveFilter.FieldRegistry.add_field(:status, :enum,
            label: "Status",
            options: [
              {"Pending", :pending},
              {"In Progress", :in_progress},
              {"Completed", :completed}
            ],
            default_operator: :in,
            multiple: true
          )
          |> LiveFilter.FieldRegistry.add_field(:priority, MyApp.PriorityField.new(),
            label: "Priority",
            icon: "hero-flag"
          )
        end
      end
  """

  alias LiveFilter.Field

  defstruct fields: %{}, groups: [], metadata: %{}

  @type field_config :: %{
          name: atom(),
          type: atom() | struct(),
          label: String.t(),
          operators: [atom()] | nil,
          default_operator: atom() | nil,
          required: boolean(),
          options: keyword() | map()
        }

  @type t :: %__MODULE__{
          fields: %{atom() => field_config()},
          groups: [atom()],
          metadata: map()
        }

  @doc """
  Create a new empty field registry.

  ## Options

    * `:metadata` - Any metadata to attach to the registry
  """
  def new(opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    %__MODULE__{
      fields: %{},
      groups: [],
      metadata: metadata
    }
  end

  @doc """
  Add a field to the registry.

  ## Parameters

    * `registry` - The registry to add to
    * `name` - The field name (atom)
    * `type` - Either an atom (:string, :integer, etc.) or a struct implementing Field protocol
    * `opts` - Field configuration options

  ## Options

    * `:label` - Human-readable label
    * `:operators` - List of allowed operators (nil means use type defaults)
    * `:default_operator` - Default operator (nil means use type default)
    * `:required` - Whether the field is required
    * `:placeholder` - UI placeholder text
    * `:help_text` - Help text for users
    * `:icon` - Icon identifier for UI
    * `:group` - Group name for organizing fields
    * `:options` - For enum/select fields, the available options
    * `:multiple` - For enum fields, whether multiple selection is allowed
    * `:validate` - Custom validation function
    * Any other options are stored as-is

  ## Examples

      # Simple field
      registry
      |> add_field(:title, :string, label: "Title")

      # Enum field with options
      registry
      |> add_field(:status, :enum,
        label: "Status",
        options: [{"Active", :active}, {"Inactive", :inactive}],
        default_operator: :in,
        multiple: true
      )

      # Custom field type
      registry
      |> add_field(:priority, MyApp.PriorityField.new(), label: "Priority")
  """
  def add_field(%__MODULE__{} = registry, name, type, opts \\ []) when is_atom(name) do
    field_config = build_field_config(name, type, opts)

    # Add to group if specified
    registry =
      if group = opts[:group] do
        add_to_group(registry, group, name)
      else
        registry
      end

    %{registry | fields: Map.put(registry.fields, name, field_config)}
  end

  @doc """
  Get field configuration by name.

  Returns nil if field not found.
  """
  def get_field(%__MODULE__{fields: fields}, name) when is_atom(name) do
    Map.get(fields, name)
  end

  @doc """
  Get all fields in a group.
  """
  def get_fields_in_group(%__MODULE__{} = registry, group_name) do
    registry.fields
    |> Enum.filter(fn {_name, config} ->
      config.options[:group] == group_name
    end)
    |> Enum.map(fn {name, config} -> {name, config} end)
  end

  @doc """
  Get the default operator for a field.

  Uses field config if specified, otherwise delegates to the Field protocol.
  """
  def get_default_operator(%__MODULE__{} = registry, field_name) when is_atom(field_name) do
    case get_field(registry, field_name) do
      nil -> nil
      %{default_operator: op} when not is_nil(op) -> op
      %{type: type} -> Field.default_operator(type)
    end
  end

  @doc """
  Get available operators for a field.

  Uses field config if specified, otherwise delegates to the Field protocol.
  """
  def get_operators(%__MODULE__{} = registry, field_name) when is_atom(field_name) do
    case get_field(registry, field_name) do
      nil -> []
      %{operators: ops} when is_list(ops) -> ops
      %{type: type} -> Field.operators(type)
    end
  end

  @doc """
  Get the UI component suggestion for a field.
  """
  def get_ui_component(%__MODULE__{} = registry, field_name) when is_atom(field_name) do
    case get_field(registry, field_name) do
      nil -> nil
      %{options: %{ui_component: component}} -> component
      %{type: type} -> Field.ui_component(type)
    end
  end

  @doc """
  Validate a value for a field.

  Uses custom validator if provided, otherwise delegates to Field protocol.
  """
  def validate(%__MODULE__{} = registry, field_name, value) when is_atom(field_name) do
    case get_field(registry, field_name) do
      nil ->
        {:error, "Unknown field: #{field_name}"}

      %{options: %{validate: validator}} when is_function(validator, 1) ->
        validator.(value)

      %{type: type} ->
        Field.validate(type, value)
    end
  end

  @doc """
  Convert UI value to filter value for a field.
  """
  def to_filter_value(%__MODULE__{} = registry, field_name, ui_value) when is_atom(field_name) do
    case get_field(registry, field_name) do
      nil -> nil
      %{type: type} -> Field.to_filter_value(type, ui_value)
    end
  end

  @doc """
  Convert filter value to UI value for a field.
  """
  def to_ui_value(%__MODULE__{} = registry, field_name, filter_value) when is_atom(field_name) do
    case get_field(registry, field_name) do
      nil -> filter_value
      %{type: type} -> Field.to_ui_value(type, filter_value)
    end
  end

  @doc """
  List all fields in the registry.

  Returns a list of {name, config} tuples.
  """
  def list_fields(%__MODULE__{fields: fields}) do
    Enum.map(fields, fn {name, config} -> {name, config} end)
  end

  @doc """
  Helper to create a string field configuration.
  """
  def string_field(name, label, opts \\ []) do
    {name, :string, Keyword.put(opts, :label, label)}
  end

  @doc """
  Helper to create an enum field configuration.
  """
  def enum_field(name, label, options, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:label, label)
      |> Keyword.put(:options, options)
      |> Keyword.put_new(:default_operator, :equals)

    {name, :enum, opts}
  end

  @doc """
  Helper to create a date field configuration.
  """
  def date_field(name, label, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:label, label)
      |> Keyword.put_new(:default_operator, :between)

    {name, :date, opts}
  end

  @doc """
  Helper to create a boolean field configuration.
  """
  def boolean_field(name, label, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:label, label)
      |> Keyword.put_new(:default_operator, :equals)

    {name, :boolean, opts}
  end

  @doc """
  Create a registry from a list of field definitions.

  ## Example

      fields = [
        LiveFilter.FieldRegistry.string_field(:title, "Title"),
        LiveFilter.FieldRegistry.enum_field(:status, "Status", [
          {"Active", :active},
          {"Inactive", :inactive}
        ]),
        {:custom, MyCustomField.new(), label: "Custom Field"}
      ]

      registry = LiveFilter.FieldRegistry.from_fields(fields)
  """
  def from_fields(field_definitions) when is_list(field_definitions) do
    Enum.reduce(field_definitions, new(), fn
      {name, type, opts}, registry ->
        add_field(registry, name, type, opts)
    end)
  end

  # Private functions

  defp build_field_config(name, type, opts) do
    %{
      name: name,
      type: type,
      label: Keyword.get(opts, :label, Phoenix.Naming.humanize(name)),
      operators: Keyword.get(opts, :operators),
      default_operator: Keyword.get(opts, :default_operator),
      required: Keyword.get(opts, :required, false),
      options: Enum.into(opts, %{})
    }
  end

  defp add_to_group(%__MODULE__{groups: groups} = registry, group_name, _field_name) do
    if group_name in groups do
      registry
    else
      %{registry | groups: groups ++ [group_name]}
    end
  end
end
