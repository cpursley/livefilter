defmodule LiveFilter.UrlUtils do
  @moduledoc """
  Utilities for handling URL parameter encoding and decoding.

  Provides functions to flatten nested parameter structures for proper URL encoding
  and other URL-related utilities for LiveFilter.
  """

  @doc """
  Flattens nested parameter maps into a flat structure suitable for URL encoding.

  Converts nested maps like `%{"filters" => %{"status" => %{"operator" => "in"}}}`
  into flat parameters like `[{"filters[status][operator]", "in"}]`.

  ## Examples

      iex> params = %{"filters" => %{"status" => %{"operator" => "in", "values" => ["pending"]}}}
      iex> LiveFilter.UrlUtils.flatten_and_encode_params(params)
      "filters%5Bstatus%5D%5Boperator%5D=in&filters%5Bstatus%5D%5Bvalues%5D%5B0%5D=pending"
  """
  def flatten_and_encode_params(params) when is_map(params) do
    params
    |> flatten_params()
    |> URI.encode_query()
  end

  @doc """
  Flattens nested parameters into a list of key-value tuples.

  ## Examples

      iex> params = %{"user" => %{"name" => "John", "tags" => ["admin", "user"]}}
      iex> LiveFilter.UrlUtils.flatten_params(params)
      [{"user[name]", "John"}, {"user[tags][0]", "admin"}, {"user[tags][1]", "user"}]
  """
  def flatten_params(map, prefix \\ "") when is_map(map) do
    map
    |> Enum.flat_map(fn {key, value} ->
      new_key = if prefix == "", do: to_string(key), else: "#{prefix}[#{key}]"
      flatten_value(value, new_key)
    end)
  end

  # Private helpers

  defp flatten_value(value, key) when is_map(value) do
    flatten_params(value, key)
  end

  defp flatten_value(value, key) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} ->
      flatten_value(item, "#{key}[#{index}]")
    end)
  end

  defp flatten_value(value, key) do
    [{key, to_string(value)}]
  end
end
