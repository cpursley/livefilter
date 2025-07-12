defmodule LiveFilter.EventRouter do
  @moduledoc """
  Optional event routing helper for dynamic filter events.

  This module helps parse and route events with dynamic names like
  "filter_status_changed" or "quick_filter_project_selected". It's
  completely optional - you can handle events however you prefer.

  ## Philosophy

  This is a toolkit for common patterns, not a required way of handling events.
  Use it if it helps, ignore it if it doesn't fit your needs.

  ## Examples

      # In your LiveView
      def handle_event(event, params, socket) do
        case LiveFilter.EventRouter.parse_filter_event(event) do
          {:ok, :status, :changed} ->
            # Handle status filter change

          {:ok, :date_range, :cleared} ->
            # Handle date range clear

          {:error, :no_match} ->
            # Not a filter event, handle normally
        end
      end

      # Or use the router function
      def handle_event(event, params, socket) do
        LiveFilter.EventRouter.route_event(event, params,
          handlers: %{
            status_changed: &handle_status_change/3,
            date_range_selected: &handle_date_selection/3
          },
          fallback: &handle_other_event/3
        )
      end
  """

  @doc """
  Parse a dynamic event name into components.

  ## Options

    * `:prefix` - Event prefix (default: "filter_")
    * `:separator` - Word separator (default: "_")
    * `:actions` - Recognized action suffixes (default: common actions)
    * `:fields` - Whitelist of valid fields (default: any)

  ## Examples

      # Default pattern: "filter_<field>_<action>"
      parse_filter_event("filter_status_changed")
      #=> {:ok, :status, :changed}

      parse_filter_event("filter_due_date_cleared")
      #=> {:ok, :due_date, :cleared}

      # Custom pattern: "quick_<field>_<action>"
      parse_filter_event("quick_project_selected", prefix: "quick_")
      #=> {:ok, :project, :selected}

      # Unknown event
      parse_filter_event("something_else")
      #=> {:error, :no_match}
  """
  def parse_filter_event(event_name, opts \\ []) when is_binary(event_name) do
    prefix = Keyword.get(opts, :prefix, "filter_")
    separator = Keyword.get(opts, :separator, "_")
    actions = Keyword.get(opts, :actions, default_actions())
    fields = Keyword.get(opts, :fields, :any)

    with true <- String.starts_with?(event_name, prefix),
         remainder <- String.replace_prefix(event_name, prefix, ""),
         parts <- String.split(remainder, separator),
         {:ok, field, action} <- extract_field_and_action(parts, actions) do
      # Validate field if whitelist provided
      if fields == :any || field in fields do
        {:ok, field, action}
      else
        {:error, :invalid_field}
      end
    else
      _ -> {:error, :no_match}
    end
  end

  @doc """
  Route events to appropriate handlers.

  This is a higher-level helper that combines parsing with handler dispatch.

  ## Options

    * `:handlers` - Map of "field_action" => handler function
    * `:fallback` - Function to call for non-matching events
    * `:parse_opts` - Options to pass to parse_filter_event/2

  ## Examples

      LiveFilter.EventRouter.route_event("filter_status_changed", params,
        handlers: %{
          "status_changed" => fn params, socket ->
            # Handle status change
            {:noreply, socket}
          end,
          "date_range_selected" => fn params, socket ->
            # Handle date selection
            {:noreply, socket}
          end
        },
        fallback: fn event, params, socket ->
          # Handle other events
          {:noreply, socket}
        end
      )
  """
  def route_event(event_name, params, opts) when is_binary(event_name) do
    handlers = Keyword.get(opts, :handlers, %{})
    fallback = Keyword.get(opts, :fallback)
    parse_opts = Keyword.get(opts, :parse_opts, [])
    socket = Keyword.get(opts, :socket)

    case parse_filter_event(event_name, parse_opts) do
      {:ok, field, action} ->
        handler_key = "#{field}_#{action}"

        case Map.get(handlers, handler_key) do
          nil when is_function(fallback) ->
            apply(fallback, [event_name, params, socket])

          nil ->
            {:noreply, socket}

          handler when is_function(handler, 2) ->
            handler.(params, socket)

          handler when is_function(handler, 3) ->
            handler.(field, params, socket)
        end

      {:error, _} when is_function(fallback) ->
        apply(fallback, [event_name, params, socket])

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @doc """
  Build a dynamic event name from components.

  The inverse of parse_filter_event/2.

  ## Examples

      build_event_name(:status, :changed)
      #=> "filter_status_changed"

      build_event_name(:due_date, :selected, prefix: "quick_")
      #=> "quick_due_date_selected"
  """
  def build_event_name(field, action, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "filter_")
    separator = Keyword.get(opts, :separator, "_")

    # Convert field name to use the separator
    field_str = field |> to_string() |> String.replace("_", separator)

    "#{prefix}#{field_str}#{separator}#{action}"
  end

  @doc """
  Extract value from event parameters based on common patterns.

  ## Options

    * `:type` - Expected value type (:single, :multi, :toggle, :range)
    * `:key` - Parameter key to look for

  ## Examples

      # Toggle event: %{"toggle" => "active"}
      extract_event_value(%{"toggle" => "active"}, type: :toggle)
      #=> {:toggle, "active"}

      # Select event: %{"select" => "urgent"}
      extract_event_value(%{"select" => "urgent"}, type: :single)
      #=> {:select, "urgent"}

      # Clear event: %{"clear" => true}
      extract_event_value(%{"clear" => true})
      #=> {:clear, true}
  """
  def extract_event_value(params, opts \\ []) when is_map(params) do
    _type = Keyword.get(opts, :type, :auto)
    key = Keyword.get(opts, :key)

    cond do
      # Specific key requested
      key && Map.has_key?(params, key) ->
        {:ok, Map.get(params, key)}

      # Clear action
      Map.has_key?(params, "clear") ->
        clear = Map.get(params, "clear")

        if clear == true || clear == "true" do
          {:clear, true}
        else
          {:error, :no_value}
        end

      # Toggle value
      toggle = Map.get(params, "toggle") ->
        {:toggle, toggle}

      # Select value
      select = Map.get(params, "select") ->
        {:select, select}

      # Range values
      start = Map.get(params, "start") ->
        {:range, {start, Map.get(params, "end")}}

      # Array values
      values = Map.get(params, "values") ->
        {:multi, values}

      # Single value
      value = Map.get(params, "value") ->
        {:single, value}

      true ->
        {:error, :no_value}
    end
  end

  @doc """
  Common event handler builder for filter changes.

  Returns a function that can be used as an event handler.

  ## Examples

      def handle_event(event, params, socket) do
        handler = LiveFilter.EventRouter.filter_change_handler(
          field: :status,
          type: :multi_select,
          apply_fn: &apply_filters/1
        )

        handler.(params, socket)
      end
  """
  def filter_change_handler(opts) do
    field = Keyword.fetch!(opts, :field)
    type = Keyword.get(opts, :type, :single)
    apply_fn = Keyword.get(opts, :apply_fn, & &1)

    fn params, socket ->
      case extract_event_value(params, type: type) do
        {:clear, true} ->
          socket
          |> Phoenix.Component.assign(field, default_value_for_type(type))
          |> apply_fn.()

        {:ok, value} ->
          socket
          |> Phoenix.Component.assign(field, value)
          |> apply_fn.()

        {:toggle, value} ->
          socket
          |> Phoenix.Component.assign(field, value)
          |> apply_fn.()

        {:select, value} ->
          socket
          |> Phoenix.Component.assign(field, value)
          |> apply_fn.()

        {:range, value} ->
          socket
          |> Phoenix.Component.assign(field, value)
          |> apply_fn.()

        {:multi, value} ->
          socket
          |> Phoenix.Component.assign(field, value)
          |> apply_fn.()

        {:single, value} ->
          socket
          |> Phoenix.Component.assign(field, value)
          |> apply_fn.()

        {:error, _} ->
          socket
      end
      |> then(&{:noreply, &1})
    end
  end

  # Private helpers

  defp default_actions do
    ~w(changed selected cleared toggled updated removed added)a
  end

  defp extract_field_and_action(parts, actions) do
    # Try different splits to find a valid action
    # For "due_date_changed" we want field: :due_date, action: :changed

    Enum.reduce_while(1..(length(parts) - 1), {:error, :no_match}, fn split_at, acc ->
      field_parts = Enum.take(parts, split_at)
      action_parts = Enum.drop(parts, split_at)

      potential_field = field_parts |> Enum.join("_") |> String.to_atom()
      potential_action = action_parts |> Enum.join("_") |> String.to_atom()

      if potential_action in actions do
        {:halt, {:ok, potential_field, potential_action}}
      else
        {:cont, acc}
      end
    end)
  end

  defp default_value_for_type(:multi_select), do: []
  defp default_value_for_type(:array), do: []
  defp default_value_for_type(:range), do: nil
  defp default_value_for_type(:toggle), do: false
  defp default_value_for_type(_), do: nil
end
