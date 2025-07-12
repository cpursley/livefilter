defmodule LiveFilter.SortTest do
  use ExUnit.Case, async: true

  alias LiveFilter.Sort

  describe "new/2" do
    test "creates a sort with field and direction" do
      sort = Sort.new(:due_date, :desc)

      assert sort.field == :due_date
      assert sort.direction == :desc
    end

    test "creates a sort with default ascending direction" do
      sort = Sort.new(:title)

      assert sort.field == :title
      assert sort.direction == :asc
    end

    test "creates a sort with string field" do
      sort = Sort.new("created_at", :desc)

      assert sort.field == "created_at"
      assert sort.direction == :desc
    end

    test "validates direction to default when invalid" do
      sort = Sort.new(:title, :invalid)

      assert sort.field == :title
      assert sort.direction == :asc
    end

    test "accepts atom fields" do
      sort = Sort.new(:inserted_at, :desc)

      assert sort.field == :inserted_at
      assert sort.direction == :desc
    end
  end

  describe "toggle_direction/1" do
    test "toggles from asc to desc" do
      sort = Sort.new(:title, :asc)
      toggled = Sort.toggle_direction(sort)

      assert toggled.field == :title
      assert toggled.direction == :desc
    end

    test "toggles from desc to asc" do
      sort = Sort.new(:title, :desc)
      toggled = Sort.toggle_direction(sort)

      assert toggled.field == :title
      assert toggled.direction == :asc
    end

    test "preserves field when toggling" do
      sort = Sort.new(:complex_field_name, :asc)
      toggled = Sort.toggle_direction(sort)

      assert toggled.field == :complex_field_name
    end
  end

  describe "opposite_direction/1" do
    test "returns desc for asc" do
      assert Sort.opposite_direction(:asc) == :desc
    end

    test "returns asc for desc" do
      assert Sort.opposite_direction(:desc) == :asc
    end
  end

  describe "struct behavior" do
    test "can be pattern matched" do
      sort = Sort.new(:title, :desc)

      assert %Sort{field: field, direction: direction} = sort
      assert field == :title
      assert direction == :desc
    end

    test "can be updated with struct syntax" do
      sort = Sort.new(:title, :asc)
      updated = %{sort | direction: :desc}

      assert updated.field == :title
      assert updated.direction == :desc
    end
  end

  describe "use cases" do
    test "multiple sort scenario" do
      primary_sort = Sort.new(:status, :asc)
      secondary_sort = Sort.new(:due_date, :desc)

      sorts = [primary_sort, secondary_sort]

      assert length(sorts) == 2
      assert hd(sorts).field == :status
      assert hd(tl(sorts)).field == :due_date
    end

    test "dynamic sort building" do
      fields = [:title, :created_at, :priority]

      sorts =
        Enum.map(fields, fn field ->
          Sort.new(field, :asc)
        end)

      assert length(sorts) == 3
      assert Enum.all?(sorts, fn sort -> sort.direction == :asc end)
    end
  end
end
