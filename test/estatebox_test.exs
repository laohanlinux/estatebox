defmodule EStateBoxTest do
  use ExUnit.Case
  require EStateBox.Clock
  require EStateBox.Identity
  test "the truth" do
    assert 1 + 1 == 2
  end

  test "clock module" do
    IO.puts EStateBox.Clock.timestamp
  end

  test "indetify module" do
    IO.puts EStateBox.Identity.entropy
  end
end
