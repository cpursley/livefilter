defmodule LiveFilter.Sort do
  @moduledoc """
  Represents a sort configuration for queries.

  A sort consists of:
  - field: The field to sort by (atom or string)
  - direction: :asc or :desc

  Multiple sorts can be applied in order (primary, secondary, etc.)
  """

  @type direction :: :asc | :desc

  @type t :: %__MODULE__{
          field: atom() | String.t(),
          direction: direction()
        }

  defstruct [:field, direction: :asc]

  @doc """
  Creates a new sort configuration.

  ## Examples

      iex> LiveFilter.Sort.new(:due_date, :desc)
      %LiveFilter.Sort{field: :due_date, direction: :desc}

      iex> LiveFilter.Sort.new("created_at")
      %LiveFilter.Sort{field: "created_at", direction: :asc}
  """
  def new(field, direction \\ :asc) do
    %__MODULE__{
      field: field,
      direction: validate_direction(direction)
    }
  end

  @doc """
  Toggles the direction of a sort.

  ## Examples

      iex> sort = LiveFilter.Sort.new(:title, :asc)
      iex> LiveFilter.Sort.toggle_direction(sort)
      %LiveFilter.Sort{field: :title, direction: :desc}
  """
  def toggle_direction(%__MODULE__{direction: :asc} = sort) do
    %{sort | direction: :desc}
  end

  def toggle_direction(%__MODULE__{direction: :desc} = sort) do
    %{sort | direction: :asc}
  end

  @doc """
  Returns the opposite direction.
  """
  def opposite_direction(:asc), do: :desc
  def opposite_direction(:desc), do: :asc

  defp validate_direction(direction) when direction in [:asc, :desc], do: direction
  defp validate_direction(_), do: :asc
end
