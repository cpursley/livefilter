defmodule LiveFilter.Components.ColumnSettings do
  @moduledoc """
  A component for managing table column visibility.
  Shows a gear icon that opens a dropdown with checkboxes for each column.

  ## Examples

      <.live_component
        module={LiveFilter.Components.ColumnSettings}
        id="column-settings"
        columns={@column_config}
        visible_columns={@visible_columns}
      />
  """
  use Phoenix.LiveComponent
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.DropdownMenu
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.dropdown_menu id={"#{@id}-dropdown"}>
        <.dropdown_menu_trigger>
          <.button variant="ghost" size="icon" class="h-8 w-8">
            <.icon name="hero-cog-6-tooth" class="h-4 w-4" />
          </.button>
        </.dropdown_menu_trigger>

        <.dropdown_menu_content align="end" class="w-[220px]">
          <.dropdown_menu_label>Toggle columns</.dropdown_menu_label>
          <.dropdown_menu_separator />

          <%= for {column, config} <- @columns, config.toggleable do %>
            <.dropdown_menu_item
              on-select={JS.push("toggle_column", value: %{column: column}, target: @myself)}
              class="flex items-center justify-between cursor-pointer"
            >
              <span>{config.label}</span>
              <div class="ml-auto">
                <%= if column in @visible_columns do %>
                  <.icon name="hero-check" class="h-4 w-4" />
                <% end %>
              </div>
            </.dropdown_menu_item>
          <% end %>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_column", %{"column" => column_str}, socket) do
    column_atom = String.to_existing_atom(column_str)
    current_visible = socket.assigns.visible_columns

    new_visible =
      if column_atom in current_visible do
        List.delete(current_visible, column_atom)
      else
        current_visible ++ [column_atom]
      end

    send(self(), {:column_visibility_changed, new_visible})
    {:noreply, socket}
  end
end
