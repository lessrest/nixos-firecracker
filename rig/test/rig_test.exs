defmodule RigTest do
  use ExUnit.Case
  doctest Rig

  test "greets the world" do
    assert Rig.hello() == :world
  end
end
