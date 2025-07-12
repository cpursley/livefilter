defmodule LiveFilter.QuickFiltersTest do
  use ExUnit.Case, async: true

  alias LiveFilter.QuickFilters

  describe "search_filter/2" do
    test "creates basic search filter" do
      filter = QuickFilters.search_filter("test query")

      assert filter.field == :_search
      assert filter.operator == :custom
      assert filter.value == "test query"
      assert filter.type == :string
    end

    test "trims whitespace by default" do
      filter = QuickFilters.search_filter("  test  ")
      assert filter.value == "test"
    end

    test "respects trim option when false" do
      filter = QuickFilters.search_filter("  test  ", trim: false)
      assert filter.value == "  test  "
    end

    test "returns nil for empty string" do
      assert is_nil(QuickFilters.search_filter(""))
      assert is_nil(QuickFilters.search_filter("   "))
    end

    test "returns nil for nil input" do
      assert is_nil(QuickFilters.search_filter(nil))
      assert is_nil(QuickFilters.search_filter(nil, field: :custom))
    end

    test "respects minimum length" do
      assert is_nil(QuickFilters.search_filter("ab", min_length: 3))
      assert QuickFilters.search_filter("abc", min_length: 3)
    end

    test "uses custom field and operator" do
      filter =
        QuickFilters.search_filter("john",
          field: :author_name,
          operator: :contains
        )

      assert filter.field == :author_name
      assert filter.operator == :contains
    end
  end

  describe "multi_select_filter/3" do
    test "creates filter for multiple values" do
      filter = QuickFilters.multi_select_filter(:status, [:active, :pending])

      assert filter.field == :status
      assert filter.operator == :in
      assert filter.value == [:active, :pending]
      assert filter.type == :enum
    end

    test "creates filter for single value" do
      filter = QuickFilters.multi_select_filter(:status, :active)

      assert filter.operator == :equals
      assert filter.value == :active
    end

    test "returns nil for empty list by default" do
      assert is_nil(QuickFilters.multi_select_filter(:status, []))
    end

    test "returns filter for empty list when reject_empty is false" do
      filter = QuickFilters.multi_select_filter(:status, [], reject_empty: false)
      assert filter.value == []
    end

    test "returns nil for nil value" do
      assert is_nil(QuickFilters.multi_select_filter(:status, nil))
    end

    test "uses custom operator" do
      filter =
        QuickFilters.multi_select_filter(:tags, ["urgent", "bug"],
          operator: :contains_all,
          type: :array
        )

      assert filter.operator == :contains_all
      assert filter.type == :array
    end
  end

  describe "date_range_filter/3" do
    test "creates filter for date range" do
      range = {~D[2025-01-01], ~D[2025-01-31]}
      filter = QuickFilters.date_range_filter(:created_at, range)

      assert filter.field == :created_at
      assert filter.operator == :between
      assert filter.value == range
      assert filter.type == :date
    end

    test "creates filter for single date" do
      date = ~D[2025-01-15]
      filter = QuickFilters.date_range_filter(:due_date, date)

      assert filter.operator == :equals
      assert filter.value == date
    end

    test "returns nil for nil input" do
      assert is_nil(QuickFilters.date_range_filter(:date, nil))
    end

    test "returns nil for incomplete range" do
      assert is_nil(QuickFilters.date_range_filter(:date, {nil, ~D[2025-01-31]}))
      assert is_nil(QuickFilters.date_range_filter(:date, {~D[2025-01-01], nil}))
    end

    test "uses custom operator" do
      filter = QuickFilters.date_range_filter(:created_at, ~D[2025-01-01], operator: :after)

      assert filter.operator == :after
    end

    test "handles preset strings when DateUtils is available" do
      # DateUtils is available, so this should work
      result = QuickFilters.date_range_filter(:date, "last_30_days")

      if Code.ensure_loaded?(LiveFilter.DateUtils) do
        refute is_nil(result)
      else
        assert is_nil(result)
      end
    end

    test "handles datetime ranges with proper type" do
      # Test UTC datetime range
      datetime_range = {~U[2025-07-10 00:00:00Z], ~U[2025-07-19 23:59:59Z]}
      filter = QuickFilters.date_range_filter(:inserted_at, datetime_range, type: :utc_datetime)

      assert filter.field == :inserted_at
      assert filter.operator == :between
      assert filter.value == datetime_range
      assert filter.type == :utc_datetime
    end

    test "handles datetime type parameter correctly" do
      # Test that different datetime types are preserved
      date_range = {~D[2025-07-10], ~D[2025-07-19]}

      # As date type
      date_filter = QuickFilters.date_range_filter(:field, date_range, type: :date)
      assert date_filter.type == :date

      # As datetime type
      datetime_filter = QuickFilters.date_range_filter(:field, date_range, type: :datetime)
      assert datetime_filter.type == :datetime

      # As utc_datetime type
      utc_filter = QuickFilters.date_range_filter(:field, date_range, type: :utc_datetime)
      assert utc_filter.type == :utc_datetime
    end
  end

  describe "boolean_filter/3" do
    test "creates filter for true value" do
      filter = QuickFilters.boolean_filter(:is_active, true)

      assert filter.field == :is_active
      assert filter.operator == :equals
      assert filter.value == true
      assert filter.type == :boolean
    end

    test "creates filter for false value" do
      filter = QuickFilters.boolean_filter(:is_active, false)
      assert filter.value == false
    end

    test "returns nil for non-boolean value" do
      assert is_nil(QuickFilters.boolean_filter(:field, "true"))
      assert is_nil(QuickFilters.boolean_filter(:field, 1))
    end

    test "true_only option filters out false values" do
      assert QuickFilters.boolean_filter(:urgent, true, true_only: true)
      assert is_nil(QuickFilters.boolean_filter(:urgent, false, true_only: true))
    end

    test "uses custom operator" do
      filter = QuickFilters.boolean_filter(:flag, true, operator: :is_true)
      assert filter.operator == :is_true
    end
  end

  describe "numeric_filter/3" do
    test "creates filter for integer" do
      filter = QuickFilters.numeric_filter(:age, 25)

      assert filter.field == :age
      assert filter.operator == :equals
      assert filter.value == 25
      assert filter.type == :integer
    end

    test "creates filter for float" do
      filter = QuickFilters.numeric_filter(:price, 99.99)

      assert filter.value == 99.99
      assert filter.type == :float
    end

    test "creates filter for range" do
      filter = QuickFilters.numeric_filter(:score, {80, 100}, operator: :between)

      assert filter.operator == :between
      assert filter.value == {80, 100}
      assert filter.type == :integer
    end

    test "detects float in range" do
      filter = QuickFilters.numeric_filter(:price, {10.5, 99.99}, operator: :between)
      assert filter.type == :float
    end

    test "returns nil for non-numeric value" do
      assert is_nil(QuickFilters.numeric_filter(:field, "not a number"))
    end

    test "uses custom operator" do
      filter = QuickFilters.numeric_filter(:age, 21, operator: :greater_than_or_equal)
      assert filter.operator == :greater_than_or_equal
    end

    test "overrides detected type when specified" do
      filter = QuickFilters.numeric_filter(:value, 42, type: :float)
      assert filter.type == :float
      assert filter.value == 42
    end
  end

  describe "array_filter/3" do
    test "creates array filter" do
      filter = QuickFilters.array_filter(:tags, ["urgent", "bug"])

      assert filter.field == :tags
      assert filter.operator == :contains_any
      assert filter.value == ["urgent", "bug"]
      assert filter.type == :array
    end

    test "returns nil for empty array" do
      assert is_nil(QuickFilters.array_filter(:tags, []))
    end

    test "uses custom operator" do
      filter = QuickFilters.array_filter(:tags, ["a", "b"], operator: :contains_all)
      assert filter.operator == :contains_all
    end

    test "uses custom type" do
      filter = QuickFilters.array_filter(:categories, ["a"], type: :multi_select)
      assert filter.type == :multi_select
    end
  end

  describe "from_params/2" do
    test "builds multiple filters from params" do
      params = %{
        "q" => "search term",
        "status" => ["active", "pending"],
        "urgent" => "true",
        "min_price" => "10.50"
      }

      definitions = [
        {"q", &QuickFilters.search_filter/1},
        {"status", fn v -> QuickFilters.multi_select_filter(:status, v) end},
        {"urgent",
         fn
           "true" -> QuickFilters.boolean_filter(:urgent, true)
           _ -> nil
         end},
        {"min_price",
         fn v ->
           case Float.parse(v) do
             {price, _} ->
               QuickFilters.numeric_filter(:price, price, operator: :greater_than_or_equal)

             _ ->
               nil
           end
         end}
      ]

      filters = QuickFilters.from_params(params, definitions: definitions)

      assert length(filters) == 4
      assert Enum.find(filters, &(&1.field == :_search))
      assert Enum.find(filters, &(&1.field == :status))
      assert Enum.find(filters, &(&1.field == :urgent))

      price_filter = Enum.find(filters, &(&1.field == :price))
      assert price_filter.value == 10.5
      assert price_filter.operator == :greater_than_or_equal
    end

    test "skips nil results from builders" do
      params = %{
        "q" => "",
        "active" => "false"
      }

      definitions = [
        {"q", &QuickFilters.search_filter/1},
        {"active", fn _ -> nil end}
      ]

      filters = QuickFilters.from_params(params, definitions: definitions)
      assert filters == []
    end

    test "handles prefix option" do
      params = %{
        "filter_status" => "active",
        "filter_urgent" => "true"
      }

      definitions = [
        {"status", fn v -> QuickFilters.multi_select_filter(:status, v) end},
        {"urgent",
         fn
           "true" -> QuickFilters.boolean_filter(:urgent, true)
           _ -> nil
         end}
      ]

      filters =
        QuickFilters.from_params(params,
          definitions: definitions,
          prefix: "filter_"
        )

      assert length(filters) == 2
    end
  end

  # Example handlers are documented but not unit tested here
  # since they require proper LiveView socket setup

  describe "extract_search_query/2" do
    test "extracts search query from filter group" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :_search, operator: :custom, value: "test query"}
        ]
      }

      assert QuickFilters.extract_search_query(filter_group) == "test query"
    end

    test "returns nil when no search filter exists" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :equals, value: :active}
        ]
      }

      assert is_nil(QuickFilters.extract_search_query(filter_group))
    end

    test "extracts from custom field" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :title, operator: :contains, value: "search term"}
        ]
      }

      assert QuickFilters.extract_search_query(filter_group, field: :title) == "search term"
    end

    test "respects operator option" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :_search, operator: :contains, value: "partial"},
          %LiveFilter.Filter{field: :_search, operator: :custom, value: "full"}
        ]
      }

      assert QuickFilters.extract_search_query(filter_group, operator: :contains) == "partial"
    end

    test "returns nil for empty filter group" do
      assert is_nil(QuickFilters.extract_search_query(%LiveFilter.FilterGroup{}))
    end
  end

  describe "extract_multi_select/2" do
    test "extracts multiple values from :in operator" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :in, value: [:active, :pending]}
        ]
      }

      assert QuickFilters.extract_multi_select(filter_group, :status) == [:active, :pending]
    end

    test "extracts single value from :equals operator as list" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :equals, value: :active}
        ]
      }

      assert QuickFilters.extract_multi_select(filter_group, :status) == [:active]
    end

    test "returns empty list when field not found" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :other, operator: :equals, value: :value}
        ]
      }

      assert QuickFilters.extract_multi_select(filter_group, :status) == []
    end

    test "respects single_value option" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :equals, value: :active}
        ]
      }

      assert QuickFilters.extract_multi_select(filter_group, :status, single_value: true) ==
               :active
    end

    test "handles empty value" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :in, value: []}
        ]
      }

      assert QuickFilters.extract_multi_select(filter_group, :status) == []
    end
  end

  describe "extract_date_range/2" do
    test "extracts date range from :between operator" do
      range = {~D[2025-01-01], ~D[2025-01-31]}

      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :due_date, operator: :between, value: range}
        ]
      }

      assert QuickFilters.extract_date_range(filter_group, :due_date) == range
    end

    test "extracts single date from :equals operator" do
      date = ~D[2025-01-15]

      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :due_date, operator: :equals, value: date}
        ]
      }

      assert QuickFilters.extract_date_range(filter_group, :due_date) == date
    end

    test "returns nil when field not found" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :created_at, operator: :between, value: {nil, nil}}
        ]
      }

      assert is_nil(QuickFilters.extract_date_range(filter_group, :due_date))
    end

    test "handles date time values" do
      range = {~U[2025-01-01 00:00:00Z], ~U[2025-01-31 23:59:59Z]}

      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :created_at, operator: :between, value: range}
        ]
      }

      assert QuickFilters.extract_date_range(filter_group, :created_at) == range
    end
  end

  describe "extract_boolean/2" do
    test "extracts true value" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :is_urgent, operator: :equals, value: true}
        ]
      }

      assert QuickFilters.extract_boolean(filter_group, :is_urgent) == true
    end

    test "extracts false value" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :is_active, operator: :equals, value: false}
        ]
      }

      assert QuickFilters.extract_boolean(filter_group, :is_active) == false
    end

    test "handles :is_true operator" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :is_urgent, operator: :is_true, value: true}
        ]
      }

      assert QuickFilters.extract_boolean(filter_group, :is_urgent) == true
    end

    test "handles :is_false operator" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :is_archived, operator: :is_false, value: false}
        ]
      }

      assert QuickFilters.extract_boolean(filter_group, :is_archived) == false
    end

    test "returns nil when field not found" do
      filter_group = %LiveFilter.FilterGroup{filters: []}

      assert is_nil(QuickFilters.extract_boolean(filter_group, :is_urgent))
    end

    test "respects default value option" do
      filter_group = %LiveFilter.FilterGroup{filters: []}

      assert QuickFilters.extract_boolean(filter_group, :is_active, default: false) == false
    end
  end

  describe "extract_numeric/2" do
    test "extracts integer value" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :age, operator: :equals, value: 25}
        ]
      }

      assert QuickFilters.extract_numeric(filter_group, :age) == 25
    end

    test "extracts float value" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :price, operator: :greater_than, value: 99.99}
        ]
      }

      assert QuickFilters.extract_numeric(filter_group, :price) == 99.99
    end

    test "extracts range from :between operator" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :score, operator: :between, value: {80, 100}}
        ]
      }

      assert QuickFilters.extract_numeric(filter_group, :score) == {80, 100}
    end

    test "returns nil when field not found" do
      filter_group = %LiveFilter.FilterGroup{filters: []}

      assert is_nil(QuickFilters.extract_numeric(filter_group, :count))
    end
  end

  describe "extract_array/2" do
    test "extracts array value" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :tags, operator: :contains_any, value: ["urgent", "bug"]}
        ]
      }

      assert QuickFilters.extract_array(filter_group, :tags) == ["urgent", "bug"]
    end

    test "returns empty list when field not found" do
      filter_group = %LiveFilter.FilterGroup{filters: []}

      assert QuickFilters.extract_array(filter_group, :tags) == []
    end

    test "respects default value option" do
      filter_group = %LiveFilter.FilterGroup{filters: []}

      assert QuickFilters.extract_array(filter_group, :categories, default: ["misc"]) == ["misc"]
    end
  end

  describe "extract_all/2" do
    test "extracts all standard filter types" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :_search, operator: :custom, value: "search term"},
          %LiveFilter.Filter{field: :status, operator: :in, value: [:active, :pending]},
          %LiveFilter.Filter{field: :assigned_to, operator: :equals, value: "john_doe"},
          %LiveFilter.Filter{
            field: :due_date,
            operator: :between,
            value: {~D[2025-01-01], ~D[2025-01-31]}
          },
          %LiveFilter.Filter{field: :is_urgent, operator: :equals, value: true},
          %LiveFilter.Filter{field: :priority, operator: :equals, value: 5},
          %LiveFilter.Filter{field: :tags, operator: :contains_any, value: ["bug", "feature"]}
        ]
      }

      extractors = [
        search_query: &QuickFilters.extract_search_query/1,
        selected_statuses: fn fg -> QuickFilters.extract_multi_select(fg, :status) end,
        selected_assignees: fn fg -> QuickFilters.extract_multi_select(fg, :assigned_to) end,
        date_range: fn fg -> QuickFilters.extract_date_range(fg, :due_date) end,
        is_urgent: fn fg -> QuickFilters.extract_boolean(fg, :is_urgent) end,
        priority: fn fg -> QuickFilters.extract_numeric(fg, :priority) end,
        tags: fn fg -> QuickFilters.extract_array(fg, :tags) end
      ]

      result = QuickFilters.extract_all(filter_group, extractors)

      assert result == %{
               search_query: "search term",
               selected_statuses: [:active, :pending],
               selected_assignees: ["john_doe"],
               date_range: {~D[2025-01-01], ~D[2025-01-31]},
               is_urgent: true,
               priority: 5,
               tags: ["bug", "feature"]
             }
    end

    test "handles missing values gracefully" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :equals, value: :active}
        ]
      }

      extractors = [
        search_query: &QuickFilters.extract_search_query/1,
        selected_statuses: fn fg -> QuickFilters.extract_multi_select(fg, :status) end,
        is_urgent: fn fg -> QuickFilters.extract_boolean(fg, :is_urgent, default: false) end
      ]

      result = QuickFilters.extract_all(filter_group, extractors)

      assert result == %{
               search_query: nil,
               selected_statuses: [:active],
               is_urgent: false
             }
    end

    test "applies to socket assigns when socket provided" do
      socket = %{assigns: %{existing: "value"}}

      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :_search, operator: :custom, value: "test"}
        ]
      }

      extractors = [
        search_query: &QuickFilters.extract_search_query/1
      ]

      result = QuickFilters.extract_all(filter_group, extractors, socket: socket)

      assert result.assigns.search_query == "test"
      assert result.assigns.existing == "value"
    end
  end

  describe "extract_optional_filters/2" do
    test "extracts filters not in exclusion list" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :equals, value: :active},
          %LiveFilter.Filter{field: :project, operator: :equals, value: "phoenix"},
          %LiveFilter.Filter{field: :tags, operator: :contains_any, value: ["bug", "urgent"]},
          %LiveFilter.Filter{field: :complexity, operator: :greater_than, value: 5}
        ]
      }

      # Exclude standard filters
      excluded_fields = [:status, :assigned_to, :due_date, :is_urgent, :_search]

      result = QuickFilters.extract_optional_filters(filter_group, excluded_fields)

      assert result == %{
               active_optional_filters: [:project, :tags, :complexity],
               optional_filter_values: %{
                 project: "phoenix",
                 tags: ["bug", "urgent"],
                 complexity: 5
               }
             }
    end

    test "returns empty when no optional filters" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :status, operator: :equals, value: :active},
          %LiveFilter.Filter{field: :_search, operator: :custom, value: "test"}
        ]
      }

      excluded_fields = [:status, :_search]

      result = QuickFilters.extract_optional_filters(filter_group, excluded_fields)

      assert result == %{
               active_optional_filters: [],
               optional_filter_values: %{}
             }
    end

    test "preserves order of filters" do
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :complexity, operator: :equals, value: 3},
          %LiveFilter.Filter{field: :project, operator: :equals, value: "test"},
          %LiveFilter.Filter{field: :tags, operator: :contains_any, value: ["feature"]}
        ]
      }

      result = QuickFilters.extract_optional_filters(filter_group, [])

      assert result.active_optional_filters == [:complexity, :project, :tags]
    end

    test "applies to socket when provided" do
      socket = %{assigns: %{existing: "value"}}

      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{field: :project, operator: :equals, value: "phoenix"}
        ]
      }

      result = QuickFilters.extract_optional_filters(filter_group, [:status], socket: socket)

      assert result.assigns.active_optional_filters == [:project]
      assert result.assigns.optional_filter_values == %{project: "phoenix"}
      assert result.assigns.existing == "value"
    end
  end
end
