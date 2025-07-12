defmodule LiveFilter.TypeUtilsTest do
  use ExUnit.Case, async: true
  alias LiveFilter.TypeUtils

  describe "safe_to_atom/1" do
    test "converts string to atom" do
      assert TypeUtils.safe_to_atom("pending") == :pending
      assert TypeUtils.safe_to_atom("in_progress") == :in_progress
    end

    test "preserves existing atoms" do
      assert TypeUtils.safe_to_atom(:already_atom) == :already_atom
    end

    test "converts list of strings to atoms" do
      assert TypeUtils.safe_to_atom(["pending", "active"]) == [:pending, :active]
    end

    test "handles mixed list of strings and atoms" do
      assert TypeUtils.safe_to_atom(["pending", :active, "completed"]) == [
               :pending,
               :active,
               :completed
             ]
    end

    test "preserves non-string/atom values" do
      assert TypeUtils.safe_to_atom(123) == 123
      assert TypeUtils.safe_to_atom(nil) == nil
    end
  end

  describe "safe_to_string/1" do
    test "converts atom to string" do
      assert TypeUtils.safe_to_string(:pending) == "pending"
    end

    test "preserves strings" do
      assert TypeUtils.safe_to_string("already_string") == "already_string"
    end

    test "converts other types to string" do
      assert TypeUtils.safe_to_string(123) == "123"
      assert TypeUtils.safe_to_string(true) == "true"
    end
  end

  describe "convert_to_type/2" do
    test "converts to atom type" do
      assert TypeUtils.convert_to_type("pending", :atom) == {:ok, :pending}
      assert TypeUtils.convert_to_type(:already_atom, :atom) == {:ok, :already_atom}
    end

    test "returns error for non-existent atoms" do
      assert {:error, _} = TypeUtils.convert_to_type("non_existent_atom_123456", :atom)
    end

    test "converts to string type" do
      assert TypeUtils.convert_to_type(:pending, :string) == {:ok, "pending"}
      assert TypeUtils.convert_to_type(123, :string) == {:ok, "123"}
    end

    test "converts to integer type" do
      assert TypeUtils.convert_to_type("123", :integer) == {:ok, 123}
      assert TypeUtils.convert_to_type(123, :integer) == {:ok, 123}
      assert {:error, _} = TypeUtils.convert_to_type("not_a_number", :integer)
    end

    test "converts to float type" do
      assert TypeUtils.convert_to_type("123.45", :float) == {:ok, 123.45}
      assert TypeUtils.convert_to_type(123.45, :float) == {:ok, 123.45}
      assert TypeUtils.convert_to_type(123, :float) == {:ok, 123.0}
      assert {:error, _} = TypeUtils.convert_to_type("not_a_float", :float)
    end

    test "converts to boolean type" do
      assert TypeUtils.convert_to_type("true", :boolean) == {:ok, true}
      assert TypeUtils.convert_to_type("false", :boolean) == {:ok, false}
      assert TypeUtils.convert_to_type(true, :boolean) == {:ok, true}
      assert TypeUtils.convert_to_type(false, :boolean) == {:ok, false}
    end

    test "returns error for unsupported conversions" do
      assert {:error, _} = TypeUtils.convert_to_type("value", :unsupported_type)
    end
  end
end
