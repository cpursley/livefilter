defmodule LiveFilter.Components.SortableHeader do
  @moduledoc """
  A sortable table header component that displays sort direction indicators
  and handles click events for sorting.

  ## Examples

      <.sortable_header
        field={:due_date}
        label="Due Date"
        current_sort={@current_sort}
        phx-click="sort_by"
      />
  """
  use Phoenix.Component

  attr(:field, :atom, required: true)
  attr(:label, :string, required: true)
  attr(:current_sort, :any, default: nil)
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(phx-click phx-target))

  def sortable_header(assigns) do
    assigns = assign(assigns, :sort_info, get_sort_info(assigns))

    ~H"""
    <th
      class={[
        "cursor-pointer select-none hover:bg-muted/50 transition-colors font-medium",
        @class
      ]}
      {@rest}
      phx-value-field={@field}
      data-shift-click="true"
    >
      <div class="flex items-center gap-1.5">
        <span>{@label}</span>
        <%= if @sort_info.is_active do %>
          <div class="flex items-center gap-0.5">
            <%= if @sort_info.sort_index do %>
              <span class="text-xs text-muted-foreground">{@sort_info.sort_index}</span>
            <% end %>
            <span class={[
              if(@sort_info.is_asc, do: "hero-chevron-up", else: "hero-chevron-down"),
              "h-3 w-3"
            ]} />
          </div>
        <% else %>
          <span class="hero-chevron-up-down h-4 w-4 text-muted-foreground" />
        <% end %>
      </div>
    </th>
    """
  end

  defp get_sort_info(%{current_sort: nil}), do: %{is_active: false, is_asc: true, sort_index: nil}

  defp get_sort_info(%{current_sort: %{field: field, direction: direction}, field: field}) do
    %{is_active: true, is_asc: direction == :asc, sort_index: nil}
  end

  defp get_sort_info(%{current_sort: current_sort, field: field}) when is_list(current_sort) do
    case Enum.find_index(current_sort, &(&1.field == field)) do
      nil ->
        %{is_active: false, is_asc: true, sort_index: nil}

      index ->
        sort = Enum.at(current_sort, index)

        %{
          is_active: true,
          is_asc: sort.direction == :asc,
          sort_index: if(length(current_sort) > 1, do: index + 1, else: nil)
        }
    end
  end

  defp get_sort_info(_), do: %{is_active: false, is_asc: true, sort_index: nil}
end
