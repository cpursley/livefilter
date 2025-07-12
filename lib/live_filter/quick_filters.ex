defmodule LiveFilter.QuickFilters do
  @moduledoc """
  Composable filter builder functions for common patterns.

  This module provides simple, focused functions for creating filters.
  Each function returns a Filter struct that can be used individually
  or combined with others. There's no magic - just convenience functions
  that save you from writing boilerplate.

  ## Philosophy

  These are building blocks, not a framework. Use what you need,
  ignore what you don't, and write your own when these don't fit.

  ## Examples

      # Use individual builders
      search = QuickFilters.search_filter("user input")
      status = QuickFilters.multi_select_filter(:status, [:active, :pending])
      date = QuickFilters.date_range_filter(:created_at, {~D[2025-01-01], ~D[2025-01-31]})
      
      # Combine into a filter group
      filter_group = %FilterGroup{
        filters: [search, status, date] |> Enum.reject(&is_nil/1)
      }
      
      # Or use in your own functions
      def build_my_filters(params) do
        [
          params["q"] && QuickFilters.search_filter(params["q"]),
          params["urgent"] == "true" && QuickFilters.boolean_filter(:is_urgent, true),
          # ... your custom logic
        ]
        |> Enum.reject(&is_nil/1)
      end
  """

  alias LiveFilter.Filter

  @doc """
  Create a search filter.

  By default creates a virtual `_search` filter that your application
  can expand to search multiple fields. You can customize everything.

  ## Options

    * `:field` - Field name (default: `:_search`)
    * `:operator` - Operator to use (default: `:custom`)
    * `:type` - Field type (default: `:string`)
    * `:min_length` - Minimum query length to create filter (default: 0)
    * `:trim` - Whether to trim whitespace (default: true)

  ## Examples

      # Simple search
      QuickFilters.search_filter("user query")
      
      # Search specific field
      QuickFilters.search_filter("john", field: :author_name, operator: :contains)
      
      # Require minimum length
      QuickFilters.search_filter(query, min_length: 3)

  Returns nil if query is empty or below min_length.
  """
  def search_filter(query, opts \\ [])
  def search_filter(nil, _opts), do: nil

  def search_filter(query, opts) when is_binary(query) do
    field = Keyword.get(opts, :field, :_search)
    operator = Keyword.get(opts, :operator, :custom)
    type = Keyword.get(opts, :type, :string)
    min_length = Keyword.get(opts, :min_length, 0)
    trim = Keyword.get(opts, :trim, true)

    query = if trim, do: String.trim(query), else: query

    if query != "" && String.length(query) >= min_length do
      %Filter{
        field: field,
        operator: operator,
        value: query,
        type: type
      }
    else
      nil
    end
  end

  @doc """
  Create a multi-select filter for enum fields.

  ## Options

    * `:operator` - Operator to use (default: `:in` for lists, `:equals` for single values)
    * `:type` - Field type (default: `:enum`)
    * `:reject_empty` - Whether to return nil for empty values (default: true)

  ## Examples

      # Multiple values
      QuickFilters.multi_select_filter(:status, [:active, :pending])
      
      # Single value (uses :equals operator)
      QuickFilters.multi_select_filter(:status, :active)
      
      # Force operator
      QuickFilters.multi_select_filter(:tags, ["urgent", "bug"], operator: :contains_all)
  """
  def multi_select_filter(field, values, opts \\ []) do
    type = Keyword.get(opts, :type, :enum)
    reject_empty = Keyword.get(opts, :reject_empty, true)

    cond do
      is_nil(values) && reject_empty ->
        nil

      is_list(values) && values == [] && reject_empty ->
        nil

      is_list(values) ->
        operator = Keyword.get(opts, :operator, :in)

        %Filter{
          field: field,
          operator: operator,
          value: values,
          type: type
        }

      true ->
        operator = Keyword.get(opts, :operator, :equals)

        %Filter{
          field: field,
          operator: operator,
          value: values,
          type: type
        }
    end
  end

  @doc """
  Create a date range filter.

  Handles both date tuples and preset strings.

  ## Options

    * `:operator` - Operator to use (default: `:between` for ranges, `:equals` for single dates)
    * `:type` - Field type (default: `:date`)
    * `:timezone` - Timezone for date calculations (default: "Etc/UTC")

  ## Examples

      # Date range
      QuickFilters.date_range_filter(:created_at, {~D[2025-01-01], ~D[2025-01-31]})
      
      # Single date
      QuickFilters.date_range_filter(:due_date, ~D[2025-01-15])
      
      # Preset (requires LiveFilter.DateUtils)
      QuickFilters.date_range_filter(:created_at, "last_30_days")
  """
  def date_range_filter(field, date_or_range, opts \\ []) do
    type = Keyword.get(opts, :type, :date)

    case date_or_range do
      nil ->
        nil

      {start_date, end_date} = range when not is_nil(start_date) and not is_nil(end_date) ->
        operator = Keyword.get(opts, :operator, :between)

        %Filter{
          field: field,
          operator: operator,
          value: range,
          type: type
        }

      %Date{} = date ->
        operator = Keyword.get(opts, :operator, :equals)

        %Filter{
          field: field,
          operator: operator,
          value: date,
          type: type
        }

      preset when is_binary(preset) ->
        # Try to parse preset if DateUtils is available
        if Code.ensure_loaded?(LiveFilter.DateUtils) do
          case apply(LiveFilter.DateUtils, :parse_date_range, [preset, type]) do
            nil -> nil
            parsed_range -> date_range_filter(field, parsed_range, opts)
          end
        else
          nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Create a boolean filter.

  ## Options

    * `:operator` - Operator to use (default: `:equals`)
    * `:true_only` - Only create filter for true values (default: false)

  ## Examples

      # Simple boolean
      QuickFilters.boolean_filter(:is_active, true)
      
      # Only filter when true
      QuickFilters.boolean_filter(:is_urgent, value, true_only: true)
  """
  def boolean_filter(field, value, opts \\ []) do
    operator = Keyword.get(opts, :operator, :equals)
    true_only = Keyword.get(opts, :true_only, false)

    cond do
      true_only && value != true ->
        nil

      is_boolean(value) ->
        %Filter{
          field: field,
          operator: operator,
          value: value,
          type: :boolean
        }

      true ->
        nil
    end
  end

  @doc """
  Create a numeric filter.

  ## Options

    * `:operator` - Operator (default: `:equals`)
    * `:type` - `:integer` or `:float` (default: auto-detect)

  ## Examples

      # Exact value
      QuickFilters.numeric_filter(:price, 99.99)
      
      # Comparison
      QuickFilters.numeric_filter(:age, 21, operator: :greater_than_or_equal)
      
      # Range
      QuickFilters.numeric_filter(:score, {80, 100}, operator: :between)
  """
  def numeric_filter(field, value, opts \\ []) do
    operator = Keyword.get(opts, :operator, :equals)

    {value, type} =
      case value do
        {min, max} when is_number(min) and is_number(max) ->
          type = if is_integer(min) && is_integer(max), do: :integer, else: :float
          {{min, max}, type}

        num when is_integer(num) ->
          {num, :integer}

        num when is_float(num) ->
          {num, :float}

        _ ->
          {nil, nil}
      end

    if value do
      type = Keyword.get(opts, :type, type)

      %Filter{
        field: field,
        operator: operator,
        value: value,
        type: type
      }
    else
      nil
    end
  end

  @doc """
  Create an array/tags filter.

  ## Options

    * `:operator` - Operator (default: `:contains_any`)
    * `:type` - Field type (default: `:array`)

  ## Examples

      # Contains any
      QuickFilters.array_filter(:tags, ["urgent", "bug"])
      
      # Contains all
      QuickFilters.array_filter(:tags, ["urgent", "bug"], operator: :contains_all)
  """
  def array_filter(field, values, opts \\ []) when is_list(values) do
    operator = Keyword.get(opts, :operator, :contains_any)
    type = Keyword.get(opts, :type, :array)

    if values == [] do
      nil
    else
      %Filter{
        field: field,
        operator: operator,
        value: values,
        type: type
      }
    end
  end

  @doc """
  Build multiple filters from a parameter map.

  This is a convenience function for handling common parameter patterns.

  ## Options

    * `:definitions` - List of {param_key, builder_fun} tuples
    * `:prefix` - Parameter key prefix to strip

  ## Examples

      params = %{
        "q" => "search term",
        "status" => ["active", "pending"],
        "urgent" => "true"
      }
      
      filters = QuickFilters.from_params(params,
        definitions: [
          {"q", fn v -> search_filter(v) end},
          {"status", fn v -> multi_select_filter(:status, v) end},
          {"urgent", fn "true" -> boolean_filter(:urgent, true); _ -> nil end}
        ]
      )
  """
  def from_params(params, opts \\ []) when is_map(params) do
    definitions = Keyword.get(opts, :definitions, [])
    prefix = Keyword.get(opts, :prefix, "")

    Enum.reduce(definitions, [], fn {param_key, builder}, acc ->
      key = if prefix != "", do: "#{prefix}#{param_key}", else: param_key

      case Map.get(params, key) do
        nil ->
          acc

        value ->
          case builder.(value) do
            nil -> acc
            filter -> [filter | acc]
          end
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Example event handler for search with debounce.

  This is just an example - implement your own based on your needs.
  """
  def example_search_handler(socket, query, opts \\ []) do
    debounce_ms = Keyword.get(opts, :debounce, 300)

    # Cancel previous timer if exists
    if timer = socket.assigns[:search_timer] do
      Process.cancel_timer(timer)
    end

    # Set new timer
    timer = Process.send_after(self(), {:apply_search, query}, debounce_ms)

    Phoenix.Component.assign(socket, search_timer: timer, search_query: query)
  end

  @doc """
  Example handler for multi-select toggle.

  This is just an example pattern.
  """
  def example_multi_select_handler(socket, field, value, :toggle) do
    current = socket.assigns[field] || []

    updated =
      if value in current do
        List.delete(current, value)
      else
        [value | current]
      end

    Phoenix.Component.assign(socket, field, updated)
  end

  def example_multi_select_handler(socket, field, values, :replace) do
    Phoenix.Component.assign(socket, field, values)
  end

  # Extraction Functions for Filter State Recovery

  @doc """
  Extract search query from a filter group.

  Looks for search filters and returns the query value.

  ## Options

    * `:field` - Field to look for (default: `:_search`)
    * `:operator` - Operator to match (default: any)

  ## Examples

      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :_search, operator: :custom, value: "search term"}
        ]
      }
      
      QuickFilters.extract_search_query(filter_group)
      #=> "search term"
  """
  def extract_search_query(filter_group, opts \\ []) do
    field = Keyword.get(opts, :field, :_search)
    operator = Keyword.get(opts, :operator, nil)

    filter = find_filter(filter_group, field, operator)
    if filter, do: filter.value, else: nil
  end

  @doc """
  Extract multi-select values from a filter group.

  Returns a list of selected values for enum/select fields.

  ## Options

    * `:single_value` - Return single value instead of list for :equals (default: false)

  ## Examples

      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :status, operator: :in, value: [:active, :pending]}
        ]
      }
      
      QuickFilters.extract_multi_select(filter_group, :status)
      #=> [:active, :pending]
  """
  def extract_multi_select(filter_group, field, opts \\ []) do
    single_value = Keyword.get(opts, :single_value, false)

    case find_filter(filter_group, field) do
      nil ->
        if single_value, do: nil, else: []

      %{operator: :in, value: values} when is_list(values) ->
        if single_value && length(values) == 1, do: hd(values), else: values

      %{operator: :equals, value: value} ->
        if single_value, do: value, else: [value]

      _ ->
        if single_value, do: nil, else: []
    end
  end

  @doc """
  Extract date range from a filter group.

  Returns the date value or range tuple.

  ## Examples

      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :due_date, operator: :between, value: {~D[2025-01-01], ~D[2025-01-31]}}
        ]
      }
      
      QuickFilters.extract_date_range(filter_group, :due_date)
      #=> {~D[2025-01-01], ~D[2025-01-31]}
  """
  def extract_date_range(filter_group, field) do
    case find_filter(filter_group, field) do
      nil -> nil
      filter -> filter.value
    end
  end

  @doc """
  Extract boolean value from a filter group.

  ## Options

    * `:default` - Default value if not found (default: nil)

  ## Examples

      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :is_urgent, operator: :equals, value: true}
        ]
      }
      
      QuickFilters.extract_boolean(filter_group, :is_urgent)
      #=> true
  """
  def extract_boolean(filter_group, field, opts \\ []) do
    default = Keyword.get(opts, :default, nil)

    case find_filter(filter_group, field) do
      nil ->
        default

      %{operator: op, value: value} when op in [:equals, :is_true, :is_false] ->
        value

      _ ->
        default
    end
  end

  @doc """
  Extract numeric value from a filter group.

  Returns the numeric value or range.

  ## Examples

      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :price, operator: :greater_than, value: 99.99}
        ]
      }
      
      QuickFilters.extract_numeric(filter_group, :price)
      #=> 99.99
  """
  def extract_numeric(filter_group, field) do
    case find_filter(filter_group, field) do
      nil -> nil
      filter -> filter.value
    end
  end

  @doc """
  Extract array value from a filter group.

  ## Options

    * `:default` - Default value if not found (default: [])

  ## Examples

      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :tags, operator: :contains_any, value: ["urgent", "bug"]}
        ]
      }
      
      QuickFilters.extract_array(filter_group, :tags)
      #=> ["urgent", "bug"]
  """
  def extract_array(filter_group, field, opts \\ []) do
    default = Keyword.get(opts, :default, [])

    case find_filter(filter_group, field) do
      nil -> default
      filter -> filter.value
    end
  end

  @doc """
  Extract multiple filter values at once.

  ## Options

    * `:socket` - If provided, applies values to socket assigns

  ## Examples

      extractors = [
        search_query: &extract_search_query/1,
        selected_statuses: fn fg -> extract_multi_select(fg, :status) end,
        is_urgent: fn fg -> extract_boolean(fg, :is_urgent, default: false) end
      ]
      
      result = QuickFilters.extract_all(filter_group, extractors)
      #=> %{search_query: "test", selected_statuses: [:active], is_urgent: false}
      
      # With socket
      socket = QuickFilters.extract_all(filter_group, extractors, socket: socket)
  """
  def extract_all(filter_group, extractors, opts \\ []) do
    socket = Keyword.get(opts, :socket)

    values =
      Enum.reduce(extractors, %{}, fn {key, extractor}, acc ->
        Map.put(acc, key, extractor.(filter_group))
      end)

    if socket do
      Enum.reduce(values, socket, fn {key, value}, acc ->
        assign_to_socket_or_map(acc, key, value)
      end)
    else
      values
    end
  end

  @doc """
  Extract optional filters (filters not in exclusion list).

  Returns a map with `:active_optional_filters` and `:optional_filter_values`.

  ## Options

    * `:socket` - If provided, applies values to socket assigns

  ## Examples

      excluded = [:status, :_search]
      result = QuickFilters.extract_optional_filters(filter_group, excluded)
      #=> %{
      #=>   active_optional_filters: [:project, :tags],
      #=>   optional_filter_values: %{project: "phoenix", tags: ["bug"]}
      #=> }
  """
  def extract_optional_filters(filter_group, excluded_fields, opts \\ []) do
    socket = Keyword.get(opts, :socket)

    {active_filters, filter_values} =
      filter_group.filters
      |> Enum.reject(fn filter -> filter.field in excluded_fields end)
      |> Enum.reduce({[], %{}}, fn filter, {fields, values} ->
        {[filter.field | fields], Map.put(values, filter.field, filter.value)}
      end)

    active_filters = Enum.reverse(active_filters)

    result = %{
      active_optional_filters: active_filters,
      optional_filter_values: filter_values
    }

    if socket do
      socket
      |> assign_to_socket_or_map(:active_optional_filters, active_filters)
      |> assign_to_socket_or_map(:optional_filter_values, filter_values)
    else
      result
    end
  end

  # Helper function to find a filter by field and optional operator
  defp find_filter(filter_group, field, operator \\ nil) do
    Enum.find(filter_group.filters, fn filter ->
      filter.field == field && (is_nil(operator) || filter.operator == operator)
    end)
  end

  # Helper to handle both Phoenix sockets and test maps
  defp assign_to_socket_or_map(socket_or_map, key, value) do
    case socket_or_map do
      %{assigns: _} = map when not is_struct(map) ->
        # Test case - simple map with assigns
        put_in(map, [:assigns, key], value)

      socket ->
        # Real Phoenix socket
        Phoenix.Component.assign(socket, key, value)
    end
  end
end
