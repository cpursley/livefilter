defmodule LiveFilter.UrlUtilsTest do
  use ExUnit.Case, async: true

  alias LiveFilter.UrlUtils

  describe "flatten_and_encode_params/1" do
    test "flattens simple nested map" do
      params = %{
        "filters" => %{
          "status" => %{
            "operator" => "in",
            "type" => "enum"
          }
        }
      }

      result = UrlUtils.flatten_and_encode_params(params)
      assert is_binary(result)

      # Decode to verify structure
      decoded = URI.decode_query(result)
      assert decoded["filters[status][operator]"] == "in"
      assert decoded["filters[status][type]"] == "enum"
    end

    test "handles arrays correctly" do
      params = %{
        "filters" => %{
          "status" => %{
            "values" => ["pending", "active"]
          }
        }
      }

      result = UrlUtils.flatten_and_encode_params(params)
      decoded = URI.decode_query(result)

      assert decoded["filters[status][values][0]"] == "pending"
      assert decoded["filters[status][values][1]"] == "active"
    end

    test "handles empty map" do
      result = UrlUtils.flatten_and_encode_params(%{})
      assert result == ""
    end

    test "handles complex nested structure" do
      params = %{
        "filters" => %{
          "status" => %{
            "operator" => "in",
            "values" => ["pending"],
            "type" => "enum"
          },
          "due_date" => %{
            "operator" => "between",
            "start" => "2025-01-01",
            "end" => "2025-01-31",
            "type" => "date"
          }
        },
        "sort" => %{
          "field" => "created_at",
          "direction" => "desc"
        },
        "page" => "2",
        "per_page" => "25"
      }

      result = UrlUtils.flatten_and_encode_params(params)
      decoded = URI.decode_query(result)

      # Verify all nested keys are flattened correctly
      assert decoded["filters[status][operator]"] == "in"
      assert decoded["filters[status][values][0]"] == "pending"
      assert decoded["filters[due_date][start]"] == "2025-01-01"
      assert decoded["sort[field]"] == "created_at"
      assert decoded["page"] == "2"
    end
  end

  describe "flatten_params/2" do
    test "returns list of key-value tuples" do
      params = %{"user" => %{"name" => "John"}}
      result = UrlUtils.flatten_params(params)

      assert result == [{"user[name]", "John"}]
    end

    test "handles array values" do
      params = %{"tags" => ["admin", "user"]}
      result = UrlUtils.flatten_params(params)

      assert result == [{"tags[0]", "admin"}, {"tags[1]", "user"}]
    end

    test "handles nested arrays" do
      params = %{"filters" => %{"status" => %{"values" => ["pending", "active"]}}}
      result = UrlUtils.flatten_params(params)

      expected = [
        {"filters[status][values][0]", "pending"},
        {"filters[status][values][1]", "active"}
      ]

      assert result == expected
    end

    test "handles mixed data types in arrays" do
      params = %{"mixed" => [1, "string", true]}
      result = UrlUtils.flatten_params(params)

      expected = [
        {"mixed[0]", "1"},
        {"mixed[1]", "string"},
        {"mixed[2]", "true"}
      ]

      assert result == expected
    end

    test "handles deeply nested structures" do
      params = %{
        "level1" => %{
          "level2" => %{
            "level3" => %{
              "array" => ["item1", "item2"],
              "value" => "test"
            }
          }
        }
      }

      result = UrlUtils.flatten_params(params)

      expected = [
        {"level1[level2][level3][array][0]", "item1"},
        {"level1[level2][level3][array][1]", "item2"},
        {"level1[level2][level3][value]", "test"}
      ]

      assert Enum.sort(result) == Enum.sort(expected)
    end
  end

  describe "integration with Phoenix URL parsing" do
    test "round-trip through URL encoding preserves array structure" do
      # Start with our nested structure
      original_params = %{
        "filters" => %{
          "status" => %{
            "values" => ["pending", "active"],
            "operator" => "in",
            "type" => "enum"
          }
        }
      }

      # Flatten and encode
      flattened = UrlUtils.flatten_params(original_params)
      query_string = URI.encode_query(flattened)

      # Parse back like Phoenix would
      phoenix_parsed = URI.decode_query(query_string)

      # Verify the flat structure is correct
      assert phoenix_parsed["filters[status][values][0]"] == "pending"
      assert phoenix_parsed["filters[status][values][1]"] == "active"
      assert phoenix_parsed["filters[status][operator]"] == "in"
      assert phoenix_parsed["filters[status][type]"] == "enum"
    end
  end
end
