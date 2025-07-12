defmodule LiveFilter.FilterTest do
  use ExUnit.Case, async: true

  alias LiveFilter.Filter

  describe "new/1" do
    test "creates a filter with all required fields" do
      filter = %Filter{
        field: :status,
        operator: :equals,
        value: :pending,
        type: :enum
      }

      assert filter.field == :status
      assert filter.operator == :equals
      assert filter.value == :pending
      assert filter.type == :enum
    end

    test "creates a filter with string field" do
      filter = %Filter{
        field: :title,
        operator: :contains,
        value: "bug",
        type: :string
      }

      assert filter.field == :title
      assert filter.operator == :contains
      assert filter.value == "bug"
      assert filter.type == :string
    end

    test "creates a filter with boolean field" do
      filter = %Filter{
        field: :is_urgent,
        operator: :is_true,
        value: true,
        type: :boolean
      }

      assert filter.field == :is_urgent
      assert filter.operator == :is_true
      assert filter.value == true
      assert filter.type == :boolean
    end

    test "creates a filter with date range" do
      start_date = ~D[2025-01-01]
      end_date = ~D[2025-01-31]

      filter = %Filter{
        field: :due_date,
        operator: :between,
        value: {start_date, end_date},
        type: :date
      }

      assert filter.field == :due_date
      assert filter.operator == :between
      assert filter.value == {start_date, end_date}
      assert filter.type == :date
    end

    test "creates a filter with array value" do
      filter = %Filter{
        field: :tags,
        operator: :contains_any,
        value: ["bug", "urgent"],
        type: :array
      }

      assert filter.field == :tags
      assert filter.operator == :contains_any
      assert filter.value == ["bug", "urgent"]
      assert filter.type == :array
    end

    test "creates a filter with numeric value" do
      filter = %Filter{
        field: :complexity,
        operator: :greater_than,
        value: 5,
        type: :integer
      }

      assert filter.field == :complexity
      assert filter.operator == :greater_than
      assert filter.value == 5
      assert filter.type == :integer
    end
  end

  describe "edge cases" do
    test "handles nil value" do
      filter = %Filter{
        field: :assigned_to,
        operator: :is_empty,
        value: nil,
        type: :string
      }

      assert filter.value == nil
    end

    test "handles empty string value" do
      filter = %Filter{
        field: :description,
        operator: :is_empty,
        value: "",
        type: :string
      }

      assert filter.value == ""
    end

    test "handles empty array value" do
      filter = %Filter{
        field: :tags,
        operator: :is_empty,
        value: [],
        type: :array
      }

      assert filter.value == []
    end

    test "handles special search field" do
      filter = %Filter{
        field: :_search,
        operator: :custom,
        value: "search term",
        type: :string
      }

      assert filter.field == :_search
      assert filter.operator == :custom
    end
  end

  describe "operator validation" do
    test "string operators" do
      string_operators = [
        :equals,
        :not_equals,
        :contains,
        :not_contains,
        :starts_with,
        :ends_with,
        :is_empty,
        :is_not_empty
      ]

      for operator <- string_operators do
        filter = %Filter{
          field: :title,
          operator: operator,
          value: "test",
          type: :string
        }

        assert filter.operator == operator
      end
    end

    test "numeric operators" do
      numeric_operators = [
        :equals,
        :not_equals,
        :greater_than,
        :greater_than_or_equal,
        :less_than,
        :less_than_or_equal,
        :between,
        :not_between
      ]

      for operator <- numeric_operators do
        value = if operator in [:between, :not_between], do: {1, 10}, else: 5

        filter = %Filter{
          field: :complexity,
          operator: operator,
          value: value,
          type: :integer
        }

        assert filter.operator == operator
      end
    end

    test "boolean operators" do
      boolean_operators = [:is_true, :is_false, :equals]

      for operator <- boolean_operators do
        value = if operator == :is_false, do: false, else: true

        filter = %Filter{
          field: :is_urgent,
          operator: operator,
          value: value,
          type: :boolean
        }

        assert filter.operator == operator
      end
    end

    test "date operators" do
      date_operators = [:equals, :not_equals, :before, :after, :between, :is_empty, :is_not_empty]

      for operator <- date_operators do
        value =
          case operator do
            :between -> {~D[2025-01-01], ~D[2025-01-31]}
            op when op in [:is_empty, :is_not_empty] -> nil
            _ -> ~D[2025-01-15]
          end

        filter = %Filter{
          field: :due_date,
          operator: operator,
          value: value,
          type: :date
        }

        assert filter.operator == operator
      end
    end

    test "array operators" do
      array_operators = [:contains_any, :contains_all, :contains_none, :is_empty, :is_not_empty]

      for operator <- array_operators do
        value = if operator in [:is_empty, :is_not_empty], do: nil, else: ["tag1", "tag2"]

        filter = %Filter{
          field: :tags,
          operator: operator,
          value: value,
          type: :array
        }

        assert filter.operator == operator
      end
    end
  end

  describe "type compatibility" do
    test "enum type with in operator accepts list" do
      filter = %Filter{
        field: :status,
        operator: :in,
        value: [:pending, :completed],
        type: :enum
      }

      assert is_list(filter.value)
      assert :pending in filter.value
      assert :completed in filter.value
    end

    test "between operator requires tuple value" do
      filter = %Filter{
        field: :estimated_hours,
        operator: :between,
        value: {10.0, 40.0},
        type: :float
      }

      assert is_tuple(filter.value)
      assert tuple_size(filter.value) == 2
    end
  end
end
