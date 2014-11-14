defmodule EStateBoxTest do
  use ExUnit.Case
  require EStateBox.Clock
  require EStateBox.Identity
  require EStateBox
  test "the truth" do
    assert 1 + 1 == 2
  end

#  test "clock module" do
    #IO.puts EStateBox.Clock.timestamp
  #end

  #test "indetify module" do
    #IO.puts EStateBox.Identity.entropy
  #end

  #test "new test" do
    #now = 1
    #s = EStateBox.new(now, fn() -> :data end)
    #assert :data == EStateBox.value(s)
    #assert now == EStateBox.last_modified(s)
    ### Nothing to expire
    #assert s == EStateBox.expire(0, s)
    ### Nothing to expire
    #assert s == EStateBox.truncate(16, s)

    ### nothing to merge
    #assert s == EStateBox.merge([s])
    ### merge the same obj
    #assert s == EStateBox.merge([s,s])
  #end

  #test "had modify test" do
    ### n is 1 to 10, s is StateBox
    #f = fn(n, s) ->
      #EStateBox.modify(n, {&:ordsets.add_element/2, [n]}, s)
    #end
    #s0 = EStateBox.new(0, fn() -> [] end)
    #s10 = :lists.foldl(f, s0, :lists.seq(1, 10))
    #assert :lists.seq(1, 10) == EStateBox.value(s10)
    #IO.puts "#{inspect s10.queue}"
    ##assert {:invalid_timestamp, {9, '<', 10}} == f.(9,s10)
  #end

#  test "batch apply op test" do
    #s = EStateBox.new(0, fn() -> [] end)
    #s0 = EStateBox.modify([], s)
    #s1 = 1..1 |> Enum.reduce(s, fn(n, acc) -> EStateBox.modify([{:ordsets, :add_element, [n]}], acc) end)
    #s10 = 1..10 |> Enum.reduce(s, fn(n, acc) -> EStateBox.modify([{:ordsets, :add_element, [n]}], acc) end)
    #assert [] == EStateBox.value(s0)
    #assert :lists.seq(1, 1) == EStateBox.value(s1)
    #assert :lists.seq(1, 10) == EStateBox.value(s10)
  #end

  #test "truncate test" do
    #f = fn(n, s) -> EStateBox.modify(n, {&:ordsets.add_element/2, [n]}, s) end
    #s10 = :lists.foldl(f, EStateBox.new(0, fn() -> [] end), :lists.seq(1, 10))
    #assert :lists.seq(1, 10) == EStateBox.value(s10)
    #assert 10 == length(s10.queue)
    #assert 10 == length((EStateBox.truncate(20, s10)).queue)
    #assert 10 == length((EStateBox.truncate(10, s10)).queue)
    #assert 1 == length((EStateBox.truncate(1, s10)).queue)
  #end

#  test "expire test" do
    #f = fn(n, s) -> EStateBox.modify(n, {&:ordsets.add_element/2, [n]}, s) end
    #s10 = :lists.foldl(f, EStateBox.new(0, fn() -> [] end), :lists.seq(1, 10))

    #assert :lists.seq(1, 10) == EStateBox.value(s10)
    #assert 10 == length(s10.queue)
    #assert 1 == length(EStateBox.expire(0, s10).queue)
    #assert 10 == length(EStateBox.expire(10, s10).queue)
    #assert 10 == length(EStateBox.expire(11, s10).queue)
  #end

  test "orddict in a statebox test" do
    s0 = EStateBox.new(0, fn() -> [] end)

    s1_a = EStateBox.modify(1, {&:orddict.store/3, [:key, :a]}, s0)
    s1_b = EStateBox.modify(1, {&:orddict.store/3, [:key, :b]}, s0)
    s1_c = EStateBox.modify(1, {&:orddict.store/3, [:c, :c]}, s0)

    s2_aa = EStateBox.modify(3, {&:orddict.store/3, [:key, :a2]}, s1_a)
    s2_ab = EStateBox.modify(2, {&:orddict.store/3, [:key, :b2]}, s1_a)
    s2_bb = EStateBox.modify(2, {&:orddict.store/3, [:key, :b2]}, s1_b)

 #   assert 1 == EStateBox.last_modified(s1_a)
    #assert 1 == EStateBox.last_modified(s1_b)

    #assert [{:key, :a}] == EStateBox.value(s1_a)
    #assert [{:key, :b}] == EStateBox.value(s1_b)

    #assert s1_a == EStateBox.merge([s0, s1_a])
    #assert s1_a == EStateBox.merge([s1_a, s0])

    ## This is a conflict that can not be resolved peacefully
    # but s1_b wins by op compare
#    assert EStateBox.value(s1_b) == EStateBox.value(EStateBox.merge([s1_b, s1_a]))
    ## s2_aa wins because it has a bigger timestamp
    #assert EStateBox.value(s2_aa) == EStateBox.value(EStateBox.merge([s2_aa, s2_ab]))
    #assert EStateBox.value(s2_aa) == EStateBox.value(EStateBox.merge([s2_aa, s2_bb]))

    ## s1_[ab] and s1_c collide in time that operations do not conflict
    #assert [{:c, :c}, {:key, :a}] == EStateBox.value(EStateBox.merge([s1_a, s1_c]))
    #assert [{:c, :c}, {:key, :a}] == EStateBox.value(EStateBox.merge([s1_c, s1_a]))

    #assert [{:c, :c}, {:key, :b}] == EStateBox.value(EStateBox.merge([s1_b, s1_c]))
    #assert [{:c, :c}, {:key, :b}] == EStateBox.value(EStateBox.merge([s1_c, s1_b]))

    ##s1_b wins over s1_a by op compare but s1_c is independent
#    assert [{:c, :c}, {:key, :b}] == EStateBox.value(EStateBox.merge([s1_c, s1_a, s1_b]))
    IO.puts "s1_c: #{inspect s1_c}"
    IO.puts "s1_b: #{inspect s1_b}"
    IO.puts "#{inspect EStateBox.merge([s1_c, s1_b, s1_a])}"
    assert [{:c, :c}, {:key, :b}] == EStateBox.value(EStateBox.merge([s1_c, s1_b, s1_a]))
  end
end
