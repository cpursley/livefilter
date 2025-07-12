defmodule LiveFilter.EventRouterTest do
  use ExUnit.Case, async: true

  alias LiveFilter.EventRouter

  describe "parse_filter_event/2" do
    test "parses default filter event pattern" do
      assert {:ok, :status, :changed} = EventRouter.parse_filter_event("filter_status_changed")

      assert {:ok, :due_date, :cleared} =
               EventRouter.parse_filter_event("filter_due_date_cleared")

      assert {:ok, :is_active, :toggled} =
               EventRouter.parse_filter_event("filter_is_active_toggled")
    end

    test "handles multi-word field names" do
      assert {:ok, :due_date, :selected} =
               EventRouter.parse_filter_event("filter_due_date_selected")

      assert {:ok, :created_at, :updated} =
               EventRouter.parse_filter_event("filter_created_at_updated")
    end

    test "returns error for non-matching events" do
      assert {:error, :no_match} = EventRouter.parse_filter_event("something_else")
      assert {:error, :no_match} = EventRouter.parse_filter_event("filter_")
      assert {:error, :no_match} = EventRouter.parse_filter_event("")
    end

    test "uses custom prefix" do
      assert {:ok, :project, :selected} =
               EventRouter.parse_filter_event("quick_project_selected", prefix: "quick_")

      assert {:error, :no_match} =
               EventRouter.parse_filter_event("filter_project_selected", prefix: "quick_")
    end

    test "validates against field whitelist" do
      assert {:ok, :status, :changed} =
               EventRouter.parse_filter_event("filter_status_changed",
                 fields: [:status, :priority]
               )

      assert {:error, :invalid_field} =
               EventRouter.parse_filter_event("filter_unknown_changed",
                 fields: [:status, :priority]
               )
    end

    test "recognizes custom actions" do
      custom_actions = [:modified, :reset, :applied]

      assert {:ok, :filter, :modified} =
               EventRouter.parse_filter_event("filter_filter_modified", actions: custom_actions)

      assert {:error, :no_match} =
               EventRouter.parse_filter_event("filter_filter_changed", actions: custom_actions)
    end

    test "handles different separators" do
      assert {:ok, :due_date, :changed} =
               EventRouter.parse_filter_event("filter-due-date-changed",
                 prefix: "filter-",
                 separator: "-"
               )
    end
  end

  describe "route_event/3" do
    test "routes to matching handler" do
      handlers = %{
        "status_changed" => fn _params, socket ->
          {:noreply, Map.put(socket, :handled, :status)}
        end,
        "priority_updated" => fn _params, socket ->
          {:noreply, Map.put(socket, :handled, :priority)}
        end
      }

      result =
        EventRouter.route_event("filter_status_changed", %{},
          handlers: handlers,
          socket: %{}
        )

      assert {:noreply, %{handled: :status}} = result
    end

    test "supports handlers with different arities" do
      handlers = %{
        "status_changed" => fn field, _params, socket ->
          {:noreply, Map.put(socket, :field, field)}
        end
      }

      result =
        EventRouter.route_event("filter_status_changed", %{},
          handlers: handlers,
          socket: %{}
        )

      assert {:noreply, %{field: :status}} = result
    end

    test "calls fallback for non-matching events" do
      fallback = fn event, _params, socket ->
        {:noreply, Map.put(socket, :fallback_event, event)}
      end

      result =
        EventRouter.route_event("unknown_event", %{},
          handlers: %{},
          fallback: fallback,
          socket: %{}
        )

      assert {:noreply, %{fallback_event: "unknown_event"}} = result
    end

    test "calls fallback when no handler matches" do
      handlers = %{
        "status_changed" => fn _, _ -> {:noreply, %{}} end
      }

      fallback = fn _, _, socket ->
        {:noreply, Map.put(socket, :no_handler, true)}
      end

      result =
        EventRouter.route_event("filter_priority_changed", %{},
          handlers: handlers,
          fallback: fallback,
          socket: %{}
        )

      assert {:noreply, %{no_handler: true}} = result
    end

    test "returns default when no fallback and no match" do
      result =
        EventRouter.route_event("unknown", %{},
          handlers: %{},
          socket: %{unchanged: true}
        )

      assert {:noreply, %{unchanged: true}} = result
    end

    test "uses custom parse options" do
      handlers = %{
        "project_selected" => fn _, socket ->
          {:noreply, Map.put(socket, :handled, true)}
        end
      }

      result =
        EventRouter.route_event("quick_project_selected", %{},
          handlers: handlers,
          parse_opts: [prefix: "quick_"],
          socket: %{}
        )

      assert {:noreply, %{handled: true}} = result
    end
  end

  describe "build_event_name/3" do
    test "builds event name from components" do
      assert EventRouter.build_event_name(:status, :changed) == "filter_status_changed"
      assert EventRouter.build_event_name(:due_date, :selected) == "filter_due_date_selected"
    end

    test "uses custom prefix" do
      assert EventRouter.build_event_name(:field, :action, prefix: "quick_") ==
               "quick_field_action"
    end

    test "uses custom separator" do
      assert EventRouter.build_event_name(:my_field, :updated,
               prefix: "filter-",
               separator: "-"
             ) == "filter-my-field-updated"
    end
  end

  describe "extract_event_value/2" do
    test "extracts toggle value" do
      assert {:toggle, "active"} = EventRouter.extract_event_value(%{"toggle" => "active"})
    end

    test "extracts select value" do
      assert {:select, "urgent"} = EventRouter.extract_event_value(%{"select" => "urgent"})
    end

    test "extracts clear action" do
      assert {:clear, true} = EventRouter.extract_event_value(%{"clear" => true})
      assert {:clear, true} = EventRouter.extract_event_value(%{"clear" => "true"})
    end

    test "extracts range values" do
      assert {:range, {"2025-01-01", "2025-01-31"}} =
               EventRouter.extract_event_value(%{
                 "start" => "2025-01-01",
                 "end" => "2025-01-31"
               })
    end

    test "extracts array values" do
      assert {:multi, ["a", "b"]} = EventRouter.extract_event_value(%{"values" => ["a", "b"]})
    end

    test "extracts single value" do
      assert {:single, "test"} = EventRouter.extract_event_value(%{"value" => "test"})
    end

    test "extracts specific key when requested" do
      params = %{"custom_key" => "custom_value", "value" => "ignored"}
      assert {:ok, "custom_value"} = EventRouter.extract_event_value(params, key: "custom_key")
    end

    test "returns error when no value found" do
      assert {:error, :no_value} = EventRouter.extract_event_value(%{})
      assert {:error, :no_value} = EventRouter.extract_event_value(%{"other" => "value"})
    end

    test "prioritizes clear over other values" do
      assert {:clear, true} =
               EventRouter.extract_event_value(%{
                 "clear" => true,
                 "value" => "ignored"
               })
    end
  end

  # filter_change_handler tests require proper LiveView test setup
  # and are skipped here to avoid socket mocking issues

  # Integration pattern tests require proper LiveView test setup
  # and are documented as examples rather than unit tested
end
