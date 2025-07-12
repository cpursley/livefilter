defmodule LiveFilter.TypeUtils do
  @moduledoc """
  Utility functions for type conversion in LiveFilter.

  Provides safe conversion utilities for values that come from
  URL parameters or other external sources.
  """

  @doc """
  Converts string values to atoms safely, preserving non-string values.

  Used for enum field values that come from URL parameters as strings
  but need to be atoms for Ecto queries.

  ## Examples

      iex> LiveFilter.TypeUtils.safe_to_atom("pending")
      :pending

      iex> LiveFilter.TypeUtils.safe_to_atom(:already_atom)
      :already_atom

      iex> LiveFilter.TypeUtils.safe_to_atom(["pending", "active"])
      [:pending, :active]

  """
  def safe_to_atom(list) when is_list(list) do
    Enum.map(list, &safe_to_atom/1)
  end

  def safe_to_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  end

  def safe_to_atom(value), do: value

  @doc """
  Converts values to string safely.

  Handles atoms, strings, and other types gracefully.

  ## Examples

      iex> LiveFilter.TypeUtils.safe_to_string(:pending)
      "pending"

      iex> LiveFilter.TypeUtils.safe_to_string("already_string")
      "already_string"

      iex> LiveFilter.TypeUtils.safe_to_string(123)
      "123"

  """
  def safe_to_string(value) when is_atom(value), do: Atom.to_string(value)
  def safe_to_string(value) when is_binary(value), do: value
  def safe_to_string(value), do: to_string(value)

  @doc """
  Safely converts a value to the specified type.

  Supports common type conversions needed by LiveFilter:
  - `:atom` - Convert strings to atoms
  - `:string` - Convert to string
  - `:integer` - Parse integers
  - `:float` - Parse floats
  - `:boolean` - Parse boolean values

  Returns `{:ok, converted_value}` or `{:error, reason}`.

  ## Examples

      iex> LiveFilter.TypeUtils.convert_to_type("pending", :atom)
      {:ok, :pending}

      iex> LiveFilter.TypeUtils.convert_to_type("123", :integer)
      {:ok, 123}

      iex> LiveFilter.TypeUtils.convert_to_type("true", :boolean)
      {:ok, true}

  """
  def convert_to_type(value, :atom) when is_binary(value) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> {:error, "Atom does not exist: #{value}"}
    end
  end

  def convert_to_type(value, :atom) when is_atom(value), do: {:ok, value}

  def convert_to_type(value, :string), do: {:ok, safe_to_string(value)}

  def convert_to_type(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid integer: #{value}"}
    end
  end

  def convert_to_type(value, :integer) when is_integer(value), do: {:ok, value}

  def convert_to_type(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "Invalid float: #{value}"}
    end
  end

  def convert_to_type(value, :float) when is_float(value), do: {:ok, value}
  def convert_to_type(value, :float) when is_integer(value), do: {:ok, value * 1.0}

  def convert_to_type("true", :boolean), do: {:ok, true}
  def convert_to_type("false", :boolean), do: {:ok, false}
  def convert_to_type(true, :boolean), do: {:ok, true}
  def convert_to_type(false, :boolean), do: {:ok, false}

  def convert_to_type(value, type),
    do: {:error, "Unsupported conversion: #{inspect(value)} to #{type}"}
end
