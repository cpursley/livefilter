defmodule LiveFilter.Components.Select do
  @moduledoc """
  A simple dropdown select component for single selection.

  Features:
  - Single selection from options
  - Configurable display format
  - Optional icon and label
  - Follows LiveFilter component patterns
  """
  use Phoenix.Component
  import SaladUI.DropdownMenu
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.Separator

  @doc """
  Renders a simple select dropdown.

  ## Options Format

  Options should be a list of tuples: `[{value, label}, ...]`

  ## Examples

      <.select
        id="sort-field"
        options={[
          {"title", "Title"},
          {"status", "Status"},
          {"created_at", "Created"}
        ]}
        selected="title"
        on_change="update_sort"
        label="Sort"
      />
  """
  attr(:id, :string, required: true)
  attr(:options, :list, required: true)
  attr(:selected, :string, default: nil)
  attr(:on_change, :any, required: true)
  attr(:placeholder, :string, default: "Select...")
  attr(:label, :string, default: nil)
  attr(:icon, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:size, :string, default: "sm", values: ~w(sm md lg))
  attr(:show_label_with_selection, :boolean, default: true)
  attr(:clearable, :boolean, default: false)

  def select(assigns) do
    ~H"""
    <div id={"#{@id}-wrapper"}>
      <.dropdown_menu id={@id}>
        <.dropdown_menu_trigger>
          <.button
            variant="outline"
            size={@size}
            class={[
              @class,
              "gap-1 items-center"
            ]}
          >
            <.icon :if={@icon} name={@icon} class="h-4 w-4" />
            {render_button_content(assigns)}
          </.button>
        </.dropdown_menu_trigger>

        <.dropdown_menu_content align="end" class="w-[200px]">
          <%= for {value, label} <- @options do %>
            <.dropdown_menu_item
              phx-click={@on_change}
              phx-value-value={value}
              class={if @selected == value, do: "bg-accent", else: ""}
            >
              <span>{label}</span>
              <%= if @selected == value do %>
                <.icon name="hero-check" class="ml-auto h-4 w-4" />
              <% end %>
            </.dropdown_menu_item>
          <% end %>

          <%= if @clearable && @selected do %>
            <.dropdown_menu_separator />
            <.dropdown_menu_item
              phx-click={@on_change}
              phx-value-value=""
              class="text-muted-foreground"
            >
              <.icon name="hero-x-mark" class="mr-2 h-4 w-4" /> Clear
            </.dropdown_menu_item>
          <% end %>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>
    """
  end

  defp render_button_content(assigns) do
    selected_label = get_selected_label(assigns.options, assigns.selected)

    cond do
      # No selection
      is_nil(assigns.selected) || assigns.selected == "" ->
        ~H"""
        {@label || @placeholder}
        """

      # Has selection with label
      assigns.label && assigns.show_label_with_selection ->
        assigns = assign(assigns, :selected_label, selected_label)

        ~H"""
        <span class="flex items-center gap-1">
          <span>{@label}</span>
          <.separator orientation="vertical" class="mx-0.5 h-4" />
          <span>{@selected_label}</span>
        </span>
        """

      # Has selection without label
      true ->
        assigns = assign(assigns, :selected_label, selected_label)

        ~H"""
        {@selected_label}
        """
    end
  end

  defp get_selected_label(options, selected_value) do
    case List.keyfind(options, selected_value, 0) do
      {_, label} -> label
      nil -> selected_value
    end
  end
end
