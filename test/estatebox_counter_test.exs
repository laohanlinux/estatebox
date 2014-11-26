defmodule EStateBox.Counter.Test do
  use ExUnit.Case
  require EStateBox
  require EStateBox.Counter
#  defp clock_step, do: 1000
  #defp default_age, do: 10 * clock_step
  #defp apply_f_inc_acc(value, clock, n, counters) do
    #key = {clock, EStateBox.Identity.entropy}
    #EStateBox.apply_op(
    #EStateBox.counter.f_inc_acc(value, default_age, key),
    #:lists.nth(n, counters)
    #)
  #end
  def add_sibling, do: :ok
  def merge_siblings(_N), do: :ok

  ## statem
  #TODO
  #Gerneate a new sibling (add_sibling)
  #update existing counter (apply_f_inc_acc)
  #Merge (up to) N siblings (merge_siblings)
  #Expiration used will be for 20 clock cycles

  defmodule State do
    defstruct [counters: [[]],
      num_counters: 1,
      value: [],
      clock: 0]
  end

  #tests
  test " initial test" do
    assert 0 === EStateBox.Counter.value([])
  end

  test "old_counter_test" do
    ## Entropy part of the tuple is 0 here, we don't need it for this test.
    #f_inc_acc(value, age, key = {timestamp, _id})
    f = fn (t, acc) ->
      EStateBox.apply_op(EStateBox.Counter.f_inc_acc(1, 10, {t, 0}), acc)
    end
    ctr1 = :lists.foldl(f, [], :lists.seq(10, 30, 2))
    assert [{{20, :acc}, 6}, {{22, 0}, 1}, {{24, 0}, 1},
      {{26, 0}, 1}, {{28, 0}, 1}, {{30, 0}, 1}] === ctr1
    assert 11 === EStateBox.Counter.value(ctr1)

    ## Should fill in only lists"seq(21, 29, 2)"
    ctr2 = :lists.foldl(f, ctr1, :lists.seq(1, 30))
    assert [{{20, :acc}, 6}, {{21, 0}, 1}, {{22, 0}, 1}, {{23, 0}, 1},
      {{24, 0}, 1}, {{25, 0}, 1}, {{26, 0}, 1}, {{27, 0}, 1}, {{28, 0}, 1},
      {{29, 0}, 1}, {{30, 0}, 1}] === ctr2
    assert EStateBox.Counter.value(ctr2) === 16
  end

  test "f_inc_acc_test" do
    # we should expect to get unique enough results from our entropy and
    # timestamp even if the frequency is high.
    fincacc =  1..1000 |> Enum.map(fn(_) -> EStateBox.Counter.f_inc_acc(1, 1000) end)
    ctr = :lists.foldl(&EStateBox.apply_op/2, [], fincacc)
    assert 1000 === EStateBox.Counter.value(ctr)
  end

  test "inc_test" do
    c0 = []
    c1 = EStateBox.Counter.inc({1, 1}, 1, c0)
    c2 = EStateBox.Counter.inc({2, 2}, 1, c1)

    assert 0 === EStateBox.Counter.value(c0)
    assert 1 === EStateBox.Counter.value(c1)
    assert 2 === EStateBox.Counter.value(c2)

    c1 = EStateBox.Counter.inc({3, 1}, 1, c1)
    assert 2 === EStateBox.Counter.value(c1)
  end

  test "merge test" do
    c0 = []
    c1 = EStateBox.Counter.inc({1, 1}, 1, c0)
    c2 = EStateBox.Counter.inc({2, 2}, 1, c1)

    assert 2 === EStateBox.Counter.value(EStateBox.Counter.merge([c0, c1, c2]))
    assert 1 === EStateBox.Counter.value(EStateBox.Counter.merge([c0, c1, c1]))
    assert 1 === EStateBox.Counter.value(EStateBox.Counter.merge([c1]))
    assert 1 === EStateBox.Counter.value(EStateBox.Counter.merge([c0, c1]))
  end

#  defp initial_state, do: %State{clock: 10000}

  #defp command(%State{counters: counters, num_counters: n, clock: clock}) do
    #oneof([{:call, __MODULE__, add_sibing, []},
      #{:call, __MODULE__, merge_siblings, [range(1, n)]},
      #{:call, __MODULE__, apply_f_inc_acc, [range(-3, 3), clock, range(1, n), counters]}])
  #end

  #defp precondition(_s, _call), do: true
  #defp postcondition(s, {:call, _, :apply_f_inc_acc, [inc, _]}, res) do
    #sane_counter(res) and (inc + :lists.sum(s.value)) === EStateBox.Counter.value(res)
  #end
  #defp postcondition(s, {:call, _, _, _}, res) do
    #:lists.all(&sane_counter/1, s.value) and (:lists.sum(s.value) === EStateBox.Counter.value(EStateBox.Counter.merge(s.counters)))
  #end

  #defp next_state(s = %State{counters: [h|t]}, _v, {:call, _, :add_sibling, []}), do: %State{s | counters: [h, h|t]}
  #defp next_state(s = %State{counters: counters}, _v, {:call, _, :merge_siblings, [n]}) do
    #[l, t] = :lists.split(n, counters)
    #%State{counters: [EStateBox.Counter.merge(l) | t]}
  #end
  #defp next_state(S = %State{counters: Counters, clock: clock}, v, {:call, _, :apply_f_inc_acc, [inc, clock, n, _c]}) do
    #counters1 = :lists.sublist(counters, n - 1) ++ [v | :lists.nthtail(n, counters)]
    #%State{s | counters: counters1, value: [inc | s.value], clock: clock + clock_step()}
  #end

  #defp sane_counter([]), do: true
  #defp sane_counter([{timestamp, id} | rest]), do: sane_counter(rest, id === :acc, timestamp)

  #defp sane_counter([a, a | _], _, _), do: false
  #defp sane_counter([{t1, _} | _], true, t0) when t1 < t0, do: false
  #defp sane_counter([{_, :acc} | _], true, _), do: false
  #defp sane_counter([{t1, :acc} | rest], false, _t0), do: sane_counter(rest, true, t1)
  #defp sane_counter([{t1, _} | rest], hasAcc, _t0), do: sane_counter(rest, hasAcc, t1)
  #defp sane_counter([], _, _), do: true


end
