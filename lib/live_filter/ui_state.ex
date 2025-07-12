defmodule LiveFilter.UIState do
  @moduledoc """
  Optional UI state management for LiveFilter.

  Provides helpers for managing UI state that maps to FilterGroup structures.
  All functions can be overridden or ignored entirely - this module is purely
  optional and designed to reduce boilerplate for common patterns.

  ## Usage

      # Use default converter
      filters = LiveFilter.UIState.ui_to_filters(ui_state)

      # Use custom converter
      filters = LiveFilter.UIState.ui_to_filters(ui_state,
        converter: &MyApp.custom_converter/2,
        fields: MyApp.field_config()
      )

      # Extract values from filters back to UI
      search_query = LiveFilter.UIState.extract_filter_value(filters, :_search)
      selected_statuses = LiveFilter.UIState.extract_filter_value(filters, :status,
        operator: :in,
        default: []
      )
  """

  alias LiveFilter.{Filter, FilterGroup}

  @type ui_state :: map()
  @type converter_fun :: (ui_state(), keyword() -> [Filter.t()])
  @type extractor_fun :: ([Filter.t()], atom(), keyword() -> any())

  @doc """
  Suggested UI state structure. Users can use any map structure they prefer.
  """
  defstruct search_query: "",
            selected_values: %{},
            date_ranges: %{},
            boolean_flags: %{},
            custom_fields: %{}

  @doc """
  Convert UI state to a list of filters.

  ## Options

    * `:converter` - Custom converter function (default: `default_converter/2`)
    * `:fields` - Field configuration for the converter
    * Any other options are passed to the converter

  ## Examples

      # Using default converter
      ui_state = %{
        search_query: "urgent",
        selected_values: %{status: [:pending, :in_progress]},
        date_ranges: %{due_date: {~D[2025-01-01], ~D[2025-01-31]}}
      }

      filters = LiveFilter.UIState.ui_to_filters(ui_state,
        fields: [
          {:status, :enum, default_op: :in},
          {:due_date, :date, default_op: :between}
        ]
      )
  """
  def ui_to_filters(ui_state, opts \\ []) do
    converter = Keyword.get(opts, :converter, &default_converter/2)
    converter.(ui_state, opts)
  end

  @doc """
  Convert a FilterGroup with UI state to filters.
  Helper for when you have both a FilterGroup and separate UI state.
  """
  def merge_ui_with_filters(%FilterGroup{} = filter_group, ui_state, opts \\ []) do
    ui_filters = ui_to_filters(ui_state, opts)

    %{filter_group | filters: filter_group.filters ++ ui_filters}
  end

  @doc """
  Extract a filter value from a list of filters or FilterGroup.

  ## Options

    * `:extractor` - Custom extractor function
    * `:operator` - Match specific operator (default: any)
    * `:default` - Default value if not found
    * `:transform` - Function to transform the extracted value

  ## Examples

      # Extract search query
      query = extract_filter_value(filters, :_search)

      # Extract multi-select with specific operator
      statuses = extract_filter_value(filters, :status,
        operator: :in,
        default: []
      )

      # Transform extracted value
      assignee_names = extract_filter_value(filters, :assigned_to,
        transform: fn ids -> Enum.map(ids, &Users.get_name/1) end
      )
  """
  def extract_filter_value(filters_or_group, field, opts \\ [])

  def extract_filter_value(%FilterGroup{filters: filters}, field, opts) do
    extract_filter_value(filters, field, opts)
  end

  def extract_filter_value(filters, field, opts) when is_list(filters) do
    extractor = Keyword.get(opts, :extractor, &default_extractor/3)
    extractor.(filters, field, opts)
  end

  @doc """
  Extract all UI-relevant values from filters at once.
  Returns a map with common UI state fields populated.

  ## Options

    * `:search_field` - Field name for search (default: `:_search`)
    * `:fields` - List of {field, type} tuples to extract
    * `:transform` - Map of field -> transform function
  """
  def filters_to_ui_state(filters_or_group, opts \\ []) do
    filters =
      case filters_or_group do
        %FilterGroup{filters: f} -> f
        filters when is_list(filters) -> filters
      end

    search_field = Keyword.get(opts, :search_field, :_search)
    fields = Keyword.get(opts, :fields, [])
    transforms = Keyword.get(opts, :transform, %{})

    base_state = %{
      search_query: extract_filter_value(filters, search_field, default: ""),
      selected_values: %{},
      date_ranges: %{},
      boolean_flags: %{}
    }

    Enum.reduce(fields, base_state, fn {field, type}, state ->
      value = extract_filter_value(filters, field)

      # Apply transform if provided
      value =
        case Map.get(transforms, field) do
          nil -> value
          transform_fn -> transform_fn.(value)
        end

      # Place in appropriate category based on type
      case type do
        :date when is_tuple(value) ->
          put_in(state, [:date_ranges, field], value)

        :boolean ->
          put_in(state, [:boolean_flags, field], value == true)

        type when type in [:enum, :array, :multi_select] ->
          put_in(state, [:selected_values, field], value || [])

        _ ->
          put_in(state, [:selected_values, field], value)
      end
    end)
  end

  # Default converter implementation
  defp default_converter(ui_state, opts) do
    fields = Keyword.get(opts, :fields, [])
    filters = []

    # Handle search query
    filters =
      if is_map(ui_state) && Map.get(ui_state, :search_query) do
        query = String.trim(Map.get(ui_state, :search_query, ""))

        if query != "" do
          search_field = Keyword.get(opts, :search_field, :_search)
          search_op = Keyword.get(opts, :search_operator, :custom)

          [
            %Filter{
              field: search_field,
              operator: search_op,
              value: query,
              type: :string
            }
            | filters
          ]
        else
          filters
        end
      else
        filters
      end

    # Handle selected values
    filters =
      if is_map(ui_state) && Map.get(ui_state, :selected_values) do
        Enum.reduce(Map.get(ui_state, :selected_values, %{}), filters, fn {field, value}, acc ->
          if value && value != [] && value != "" do
            field_config = find_field_config(fields, field)
            type = field_config[:type] || detect_type_from_value(field, value)
            operator = field_config[:default_op] || default_operator_for_type(type, value)

            [
              %Filter{
                field: field,
                operator: operator,
                value: value,
                type: type
              }
              | acc
            ]
          else
            acc
          end
        end)
      else
        filters
      end

    # Handle date ranges
    filters =
      if is_map(ui_state) && Map.get(ui_state, :date_ranges) do
        Enum.reduce(Map.get(ui_state, :date_ranges, %{}), filters, fn {field, range}, acc ->
          if range do
            [
              %Filter{
                field: field,
                operator: :between,
                value: range,
                type: :date
              }
              | acc
            ]
          else
            acc
          end
        end)
      else
        filters
      end

    # Handle boolean flags
    filters =
      if is_map(ui_state) && Map.get(ui_state, :boolean_flags) do
        Enum.reduce(Map.get(ui_state, :boolean_flags, %{}), filters, fn {field, value}, acc ->
          if value == true do
            [
              %Filter{
                field: field,
                operator: :equals,
                value: true,
                type: :boolean
              }
              | acc
            ]
          else
            acc
          end
        end)
      else
        filters
      end

    Enum.reverse(filters)
  end

  # Default extractor implementation
  defp default_extractor(filters, field, opts) do
    operator = Keyword.get(opts, :operator)
    default = Keyword.get(opts, :default)
    transform = Keyword.get(opts, :transform)

    # Find matching filter
    filter =
      Enum.find(filters, fn f ->
        f.field == field && (is_nil(operator) || f.operator == operator)
      end)

    # Extract value
    value =
      case filter do
        nil -> default
        %{value: v} -> v
      end

    # Apply transform if provided
    case transform do
      nil -> value
      fun when is_function(fun, 1) -> fun.(value)
    end
  end

  # Helper to find field configuration
  defp find_field_config(fields, field_name) do
    case Enum.find(fields, fn
           {name, _type} -> name == field_name
           {name, _type, _opts} -> name == field_name
           config when is_map(config) -> config[:field] == field_name
         end) do
      {_name, type} -> [type: type]
      {_name, type, opts} -> [type: type] ++ opts
      config when is_map(config) -> Map.to_list(config)
      _ -> []
    end
  end

  # Simple type detection based only on value type - no business logic
  defp detect_type_from_value(_field, value) do
    cond do
      is_boolean(value) -> :boolean
      # Lists are typically enum selections
      is_list(value) -> :enum
      is_integer(value) -> :integer
      is_float(value) -> :float
      true -> :string
    end
  end

  # Determine default operator based on type and value
  defp default_operator_for_type(type, value) do
    case {type, value} do
      {:enum, value} when is_list(value) -> :in
      {:enum, _} -> :equals
      {:array, _} -> :contains_any
      {:multi_select, _} -> :contains_any
      {:boolean, _} -> :equals
      {type, _} when type in [:date, :datetime] -> :between
      {type, _} when type in [:integer, :float] -> :equals
      _ -> :contains
    end
  end
end
