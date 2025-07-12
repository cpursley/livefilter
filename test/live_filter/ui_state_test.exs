defmodule LiveFilter.UIStateTest do
  use ExUnit.Case, async: true

  alias LiveFilter.{UIState, Filter, FilterGroup}

  describe "ui_to_filters/2" do
    test "uses default converter when no custom converter provided" do
      ui_state = %{
        search_query: "test query",
        selected_values: %{status: [:active, :pending]}
      }

      filters = UIState.ui_to_filters(ui_state)

      assert length(filters) == 2
      assert Enum.find(filters, &(&1.field == :_search))
      assert Enum.find(filters, &(&1.field == :status))
    end

    test "uses custom converter when provided in opts" do
      custom_converter = fn _ui_state, _opts ->
        [%Filter{field: :custom, operator: :equals, value: "test", type: :string}]
      end

      filters = UIState.ui_to_filters(%{}, converter: custom_converter)

      assert length(filters) == 1
      assert hd(filters).field == :custom
    end

    test "passes field config to converter" do
      fields = [
        {:status, :enum, default_op: :in},
        {:priority, :integer, default_op: :greater_than}
      ]

      ui_state = %{
        selected_values: %{
          status: [:pending],
          priority: 5
        }
      }

      filters = UIState.ui_to_filters(ui_state, fields: fields)

      status_filter = Enum.find(filters, &(&1.field == :status))
      assert status_filter.operator == :in
      assert status_filter.type == :enum

      priority_filter = Enum.find(filters, &(&1.field == :priority))
      assert priority_filter.operator == :greater_than
      assert priority_filter.type == :integer
    end

    test "handles empty UI state" do
      filters = UIState.ui_to_filters(%{})
      assert filters == []
    end

    test "handles nil values in UI state" do
      ui_state = %{
        search_query: nil,
        selected_values: %{status: nil},
        date_ranges: %{due_date: nil}
      }

      filters = UIState.ui_to_filters(ui_state)
      assert filters == []
    end

    test "default converter handles all standard UI patterns" do
      ui_state = %{
        search_query: "test",
        selected_values: %{
          status: [:active],
          project: "web"
        },
        date_ranges: %{
          created_at: {~D[2025-01-01], ~D[2025-01-31]}
        },
        boolean_flags: %{
          is_urgent: true,
          is_archived: false
        }
      }

      filters = UIState.ui_to_filters(ui_state)

      # Check search
      search = Enum.find(filters, &(&1.field == :_search))
      assert search.value == "test"
      assert search.operator == :custom

      # Check enums
      status = Enum.find(filters, &(&1.field == :status))
      assert status.value == [:active]
      assert status.operator == :in

      project = Enum.find(filters, &(&1.field == :project))
      assert project.value == "web"

      # Check date range
      created = Enum.find(filters, &(&1.field == :created_at))
      assert created.operator == :between
      assert created.value == {~D[2025-01-01], ~D[2025-01-31]}

      # Check boolean (only true values create filters by default)
      urgent = Enum.find(filters, &(&1.field == :is_urgent))
      assert urgent.value == true

      archived = Enum.find(filters, &(&1.field == :is_archived))
      assert is_nil(archived)
    end
  end

  describe "extract_filter_value/3" do
    setup do
      filters = [
        %Filter{field: :status, operator: :in, value: [:active, :pending], type: :enum},
        %Filter{field: :priority, operator: :equals, value: 5, type: :integer},
        %Filter{field: :_search, operator: :custom, value: "test query", type: :string}
      ]

      {:ok, filters: filters}
    end

    test "uses default extractor when none provided", %{filters: filters} do
      value = UIState.extract_filter_value(filters, :status)
      assert value == [:active, :pending]
    end

    test "uses custom extractor from opts", %{filters: filters} do
      custom_extractor = fn _filters, _field, _opts -> "custom value" end

      value = UIState.extract_filter_value(filters, :status, extractor: custom_extractor)
      assert value == "custom value"
    end

    test "handles missing fields gracefully", %{filters: filters} do
      value = UIState.extract_filter_value(filters, :missing_field)
      assert is_nil(value)
    end

    test "returns default value when field not found", %{filters: filters} do
      value = UIState.extract_filter_value(filters, :missing, default: "default")
      assert value == "default"
    end

    test "matches specific operator when provided", %{filters: filters} do
      filters =
        filters ++
          [
            %Filter{field: :status, operator: :not_in, value: [:archived], type: :enum}
          ]

      value = UIState.extract_filter_value(filters, :status, operator: :not_in)
      assert value == [:archived]
    end

    test "transforms value when transform function provided", %{filters: filters} do
      transform = fn value -> String.upcase(value) end

      value = UIState.extract_filter_value(filters, :_search, transform: transform)
      assert value == "TEST QUERY"
    end

    test "works with FilterGroup", %{filters: filters} do
      filter_group = %FilterGroup{filters: filters}

      value = UIState.extract_filter_value(filter_group, :priority)
      assert value == 5
    end
  end

  describe "filters_to_ui_state/2" do
    test "converts filters back to UI state structure" do
      filters = [
        %Filter{field: :_search, operator: :custom, value: "query", type: :string},
        %Filter{field: :status, operator: :in, value: [:active], type: :enum},
        %Filter{
          field: :due_date,
          operator: :between,
          value: {~D[2025-01-01], ~D[2025-01-31]},
          type: :date
        },
        %Filter{field: :is_urgent, operator: :equals, value: true, type: :boolean}
      ]

      ui_state =
        UIState.filters_to_ui_state(filters,
          fields: [
            {:status, :enum},
            {:due_date, :date},
            {:is_urgent, :boolean}
          ]
        )

      assert ui_state.search_query == "query"
      assert ui_state.selected_values.status == [:active]
      assert ui_state.date_ranges.due_date == {~D[2025-01-01], ~D[2025-01-31]}
      assert ui_state.boolean_flags.is_urgent == true
    end

    test "applies field transforms" do
      filters = [
        %Filter{field: :status, operator: :in, value: [:active, :pending], type: :enum}
      ]

      transforms = %{
        status: fn values -> Enum.map(values, &to_string/1) end
      }

      ui_state =
        UIState.filters_to_ui_state(filters,
          fields: [{:status, :enum}],
          transform: transforms
        )

      assert ui_state.selected_values.status == ["active", "pending"]
    end

    test "handles custom search field" do
      filters = [
        %Filter{field: :custom_search, operator: :contains, value: "test", type: :string}
      ]

      ui_state = UIState.filters_to_ui_state(filters, search_field: :custom_search)
      assert ui_state.search_query == "test"
    end
  end

  describe "merge_ui_with_filters/3" do
    test "combines existing filter group with UI state filters" do
      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :category, operator: :equals, value: "books", type: :string}
        ]
      }

      ui_state = %{
        search_query: "elixir",
        selected_values: %{status: [:available]}
      }

      merged = UIState.merge_ui_with_filters(filter_group, ui_state)

      assert length(merged.filters) == 3
      assert Enum.find(merged.filters, &(&1.field == :category))
      assert Enum.find(merged.filters, &(&1.field == :_search))
      assert Enum.find(merged.filters, &(&1.field == :status))
    end
  end
end
