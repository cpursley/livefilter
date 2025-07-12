defmodule LiveFilter.Components.FilterItem do
  @moduledoc """
  A component for rendering individual filter items with configurable UI.

  Accepts:
  - filter: The filter struct
  - field_options: List of {field, label, type, opts} tuples
  - field_value_options: Map of field => options list for enum/array fields
  - ui_components: Optional UI component configuration
  """
  use Phoenix.LiveComponent
  alias LiveFilter.FilterTypes

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-3 bg-muted/50 rounded-md border">
      <div class="w-1/4">
        <select
          id={"field-select-#{@index}"}
          name="field"
          value={to_string(@filter.field)}
          phx-change="field_changed"
          phx-target={@myself}
          class="w-full px-3 py-2 text-sm border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
        >
          <%= for {field, label, _type, _opts} <- @field_options do %>
            <option value={field} selected={field == @filter.field}>{label}</option>
          <% end %>
        </select>
      </div>

      <div class="w-1/4">
        <select
          id={"operator-select-#{@index}"}
          name="operator"
          value={to_string(@filter.operator)}
          phx-change="operator_changed"
          phx-target={@myself}
          class="w-full px-3 py-2 text-sm border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
        >
          <%= for operator <- FilterTypes.operators_for_type(@filter.type) do %>
            <option value={operator} selected={operator == @filter.operator}>
              {FilterTypes.operator_label(operator)}
            </option>
          <% end %>
        </select>
      </div>

      <%= if FilterTypes.operator_requires_value?(@filter.operator) do %>
        <div class="flex-1">
          {render_value_input(assigns)}
        </div>
      <% end %>

      <div>
        <button
          phx-click="remove_filter"
          phx-target={@myself}
          class="text-red-600 hover:bg-red-100 p-1 rounded"
          type="button"
        >
          <span class="text-lg">×</span>
        </button>
      </div>
    </div>
    """
  end

  defp render_value_input(assigns) do
    cond do
      assigns.filter.operator in [:between] and
          assigns.filter.type in [:date, :datetime, :integer, :float] ->
        render_range_input(assigns)

      assigns.filter.type == :boolean ->
        render_boolean_toggle(assigns)

      assigns.filter.type == :date ->
        render_date_input(assigns)

      assigns.filter.type == :datetime ->
        render_datetime_input(assigns)

      assigns.filter.type in [:integer, :float] ->
        render_number_input(assigns)

      assigns.filter.type == :enum and assigns.filter.field in [:status] ->
        render_enum_select(assigns)

      assigns.filter.type == :enum and assigns.filter.field in [:assigned_to, :project] ->
        render_searchable_select(assigns)

      assigns.filter.type == :array ->
        render_multi_select(assigns)

      true ->
        render_text_input(assigns)
    end
  end

  defp render_text_input(assigns) do
    ~H"""
    <input
      type="text"
      class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
      name="value"
      value={@filter.value}
      placeholder="Enter value"
      phx-change="value_changed"
      phx-target={@myself}
    />
    """
  end

  defp render_number_input(assigns) do
    ~H"""
    <input
      type="number"
      class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
      name="value"
      value={@filter.value}
      placeholder="Enter number"
      phx-change="value_changed"
      phx-target={@myself}
      step={if @filter.type == :float, do: "0.01", else: "1"}
    />
    """
  end

  defp render_date_input(assigns) do
    ~H"""
    <input
      type="date"
      class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
      name="value"
      value={@filter.value}
      phx-change="value_changed"
      phx-target={@myself}
    />
    """
  end

  defp render_boolean_toggle(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <input
        type="checkbox"
        id={"boolean-toggle-#{@index}"}
        class="h-4 w-4 rounded border-gray-300"
        name="value"
        checked={@filter.value == true}
        phx-click="toggle_boolean"
        phx-target={@myself}
      />
      <span class="text-sm text-muted-foreground">
        {if @filter.value == true, do: "Yes", else: "No"}
      </span>
    </div>
    """
  end

  defp render_range_input(assigns) do
    ~H"""
    <div class="flex gap-2 items-center">
      <%= if @filter.type == :date do %>
        <input
          type="date"
          class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
          name="min_value"
          value={get_range_min(@filter.value)}
          placeholder="From"
          phx-change="min_value_changed"
          phx-target={@myself}
          class="w-36"
        />
        <span class="text-muted-foreground">to</span>
        <input
          type="date"
          class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
          name="max_value"
          value={get_range_max(@filter.value)}
          placeholder="To"
          phx-change="max_value_changed"
          phx-target={@myself}
          class="w-36"
        />
      <% else %>
        <input
          type="number"
          class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
          name="min_value"
          value={get_range_min(@filter.value)}
          placeholder="Min"
          phx-change="min_value_changed"
          phx-target={@myself}
          class="w-24"
          step={if @filter.type == :float, do: "0.01", else: "1"}
        />
        <span class="text-muted-foreground">to</span>
        <input
          type="number"
          class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
          name="max_value"
          value={get_range_max(@filter.value)}
          placeholder="Max"
          phx-change="max_value_changed"
          phx-target={@myself}
          class="w-24"
          step={if @filter.type == :float, do: "0.01", else: "1"}
        />
      <% end %>
    </div>
    """
  end

  defp render_multi_select(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="flex flex-wrap gap-1">
        <%= if is_list(@filter.value) && length(@filter.value) > 0 do %>
          <span
            :for={value <- @filter.value}
            class="inline-flex items-center px-2 py-1 text-xs bg-gray-100 rounded"
          >
            {get_label_for_value(@filter.field, value, @field_value_options)}
            <button
              type="button"
              phx-click="remove_multi_value"
              phx-value-value={value}
              phx-target={@myself}
              class="ml-1 text-gray-500 hover:text-gray-700"
            >
              ×
            </button>
          </span>
        <% end %>
      </div>
      <select
        name="value"
        phx-change="add_multi_value"
        phx-target={@myself}
        class="w-full px-3 py-2 text-sm border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
      >
        <option value="">Add tag...</option>
        <%= for option <- get_field_options(@filter.field, @field_value_options) do %>
          <%= unless is_selected?(option.value, @filter.value) do %>
            <option value={option.value}>{option.label}</option>
          <% end %>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_datetime_input(assigns) do
    ~H"""
    <input
      type="datetime-local"
      class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md"
      name="value"
      value={format_datetime_value(@filter.value)}
      phx-change="value_changed"
      phx-target={@myself}
    />
    """
  end

  defp render_enum_select(assigns) do
    ~H"""
    <select
      name="value"
      value={@filter.value}
      phx-change="value_changed"
      phx-target={@myself}
      class="w-full px-3 py-2 text-sm border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
    >
      <option value="">All</option>
      <%= for option <- get_field_options(@filter.field, @field_value_options) do %>
        <option value={option.value} selected={option.value == @filter.value}>{option.label}</option>
      <% end %>
    </select>
    """
  end

  defp render_searchable_select(assigns) do
    ~H"""
    <select
      name="value"
      value={@filter.value}
      phx-change="value_changed"
      phx-target={@myself}
      class="w-full px-3 py-2 text-sm border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
    >
      <option value="">All</option>
      <%= for option <- get_field_options(@filter.field, @field_value_options) do %>
        <option value={option.value} selected={option.value == @filter.value}>{option.label}</option>
      <% end %>
    </select>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Ensure field_value_options has a default
    assigns = Map.put_new(assigns, :field_value_options, %{})
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("field_changed", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    {_field, _label, type, _opts} =
      Enum.find(socket.assigns.field_options, fn {f, _, _, _} -> f == field end)

    operators = FilterTypes.operators_for_type(type)
    operator = List.first(operators)

    filter = %{socket.assigns.filter | field: field, operator: operator, type: type, value: nil}

    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("operator_changed", %{"operator" => operator}, socket) do
    operator = String.to_existing_atom(operator)
    filter = %{socket.assigns.filter | operator: operator, value: nil}

    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("value_changed", %{"value" => value}, socket) do
    parsed_value = parse_value(value, socket.assigns.filter.type)
    filter = %{socket.assigns.filter | value: parsed_value}

    # Send to parent LiveView
    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("add_multi_value", %{"value" => ""}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_multi_value", %{"value" => value}, socket) do
    current_values = socket.assigns.filter.value || []
    filter = %{socket.assigns.filter | value: current_values ++ [value]}
    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("remove_multi_value", %{"value" => value}, socket) do
    current_values = socket.assigns.filter.value || []
    filter = %{socket.assigns.filter | value: List.delete(current_values, value)}
    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("min_value_changed", %{"min_value" => min_value}, socket) do
    min_val = parse_number(min_value, socket.assigns.filter.type)
    max_val = get_range_max(socket.assigns.filter.value)
    value = {min_val, max_val}

    filter = %{socket.assigns.filter | value: value}
    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("max_value_changed", %{"max_value" => max_value}, socket) do
    max_val = parse_number(max_value, socket.assigns.filter.type)
    min_val = get_range_min(socket.assigns.filter.value)
    value = {min_val, max_val}

    filter = %{socket.assigns.filter | value: value}
    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("remove_filter", _params, socket) do
    send(self(), {:filter_removed, socket.assigns.index})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_boolean", _params, socket) do
    new_value = !socket.assigns.filter.value
    filter = %{socket.assigns.filter | value: new_value}

    send(self(), {:filter_updated, socket.assigns.index, filter})
    {:noreply, assign(socket, :filter, filter)}
  end

  # Gets options for a specific field from the provided field_value_options map
  defp get_field_options(field, field_value_options) do
    Map.get(field_value_options, field, [])
  end

  defp get_label_for_value(field, value, field_value_options) do
    options = get_field_options(field, field_value_options)

    case Enum.find(options, fn opt -> opt.value == value end) do
      %{label: label} -> label
      nil -> to_string(value)
    end
  end

  defp is_selected?(value, filter_value) when is_list(filter_value) do
    Enum.member?(filter_value, value)
  end

  defp is_selected?(value, filter_value), do: value == filter_value

  defp get_range_min({min, _}), do: min
  defp get_range_min(_), do: nil

  defp get_range_max({_, max}), do: max
  defp get_range_max(_), do: nil

  defp parse_value(value, type) do
    case type do
      :integer -> parse_integer(value)
      :float -> parse_float(value)
      :boolean -> value == "true"
      :date -> parse_date(value)
      :datetime -> parse_datetime(value)
      _ -> value
    end
  end

  defp parse_integer(""), do: nil

  defp parse_integer(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_float(""), do: nil

  defp parse_float(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_number(value, :integer), do: parse_integer(value)
  defp parse_number(value, :float), do: parse_float(value)
  defp parse_number(value, _), do: value

  defp parse_date(""), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_datetime(""), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> nil
    end
  end

  defp format_datetime_value(nil), do: ""

  defp format_datetime_value(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%dT%H:%M")
  end

  defp format_datetime_value(_), do: ""
end
