defmodule ElderTest do
  use ExUnit.Case
  doctest Elder

  test "greets the world" do
    assert Elder.hello() == :world
  end
end
