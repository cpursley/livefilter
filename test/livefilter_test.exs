defmodule LiveFilterTest do
  use ExUnit.Case
  doctest LiveFilter

  test "returns correct version" do
    assert LiveFilter.version() == "0.1.0"
  end
end
