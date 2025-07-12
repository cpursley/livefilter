defmodule LiveFilter.FilterGroupTest do
  use ExUnit.Case, async: true

  alias LiveFilter.{Filter, FilterGroup}

  describe "new/0" do
    test "creates an empty filter group with defaults" do
      group = %FilterGroup{}

      assert group.filters == []
      assert group.groups == []
      assert group.conjunction == :and
    end
  end

  describe "struct operations" do
    test "adds a filter to an empty group" do
      group = %FilterGroup{}
      filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}

      updated_group = %{group | filters: group.filters ++ [filter]}

      assert length(updated_group.filters) == 1
      assert hd(updated_group.filters) == filter
    end

    test "adds multiple filters" do
      group = %FilterGroup{}
      filter1 = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      filter2 = %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}

      updated_group = %{group | filters: [filter1, filter2]}

      assert length(updated_group.filters) == 2
      assert filter1 in updated_group.filters
      assert filter2 in updated_group.filters
    end

    test "removes a filter by index" do
      filter1 = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      filter2 = %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
      group = %FilterGroup{filters: [filter1, filter2]}

      updated_group = %{group | filters: List.delete_at(group.filters, 0)}

      assert length(updated_group.filters) == 1
      assert hd(updated_group.filters) == filter2
    end

    test "handles removal with invalid index" do
      filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      group = %FilterGroup{filters: [filter]}

      # List.delete_at returns the original list for out of bounds indices
      updated_filters = List.delete_at(group.filters, 5)

      assert updated_filters == group.filters
    end

    test "handles removal with negative index" do
      filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      group = %FilterGroup{filters: [filter]}

      # List.delete_at with -1 removes the last element
      updated_group = %{group | filters: List.delete_at(group.filters, -1)}

      assert updated_group.filters == []
    end

    test "updates a filter at the given index" do
      old_filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      new_filter = %Filter{field: :status, operator: :equals, value: :completed, type: :enum}
      group = %FilterGroup{filters: [old_filter]}

      updated_group = %{group | filters: List.replace_at(group.filters, 0, new_filter)}

      assert length(updated_group.filters) == 1
      assert hd(updated_group.filters) == new_filter
    end

    test "adds a nested group" do
      main_group = %FilterGroup{}

      nested_group = %FilterGroup{
        filters: [
          %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
        ],
        conjunction: :or
      }

      updated_group = %{main_group | groups: main_group.groups ++ [nested_group]}

      assert length(updated_group.groups) == 1
      assert hd(updated_group.groups) == nested_group
    end
  end

  describe "filter counting" do
    test "counts filters in a simple group" do
      group = %FilterGroup{
        filters: [
          %Filter{field: :status, operator: :equals, value: :pending, type: :enum},
          %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
        ]
      }

      assert length(group.filters) == 2
    end

    test "checks if group has filters" do
      empty_group = %FilterGroup{}
      refute Enum.any?(empty_group.filters) || Enum.any?(empty_group.groups)

      group_with_filters = %FilterGroup{
        filters: [%Filter{field: :status, operator: :equals, value: :pending, type: :enum}]
      }

      assert Enum.any?(group_with_filters.filters)
    end
  end

  describe "conjunction types" do
    test "supports AND conjunction" do
      group = %FilterGroup{conjunction: :and}
      assert group.conjunction == :and
    end

    test "supports OR conjunction" do
      group = %FilterGroup{conjunction: :or}
      assert group.conjunction == :or
    end

    test "nested groups can have different conjunctions" do
      group = %FilterGroup{
        conjunction: :and,
        groups: [
          %FilterGroup{conjunction: :or},
          %FilterGroup{conjunction: :and}
        ]
      }

      assert group.conjunction == :and
      assert Enum.at(group.groups, 0).conjunction == :or
      assert Enum.at(group.groups, 1).conjunction == :and
    end
  end

  describe "complex scenarios" do
    test "builds a complex query structure" do
      # (status = pending AND is_urgent = true) OR (assigned_to IN [john, jane])
      group = %FilterGroup{
        conjunction: :or,
        groups: [
          %FilterGroup{
            conjunction: :and,
            filters: [
              %Filter{field: :status, operator: :equals, value: :pending, type: :enum},
              %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
            ]
          },
          %FilterGroup{
            filters: [
              %Filter{field: :assigned_to, operator: :in, value: ["john", "jane"], type: :enum}
            ]
          }
        ]
      }

      assert FilterGroup.count_filters(group) == 3
      assert FilterGroup.has_filters?(group)
    end
  end
end
