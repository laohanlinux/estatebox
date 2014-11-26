defmodule EStateBox.Counter do
  require EStateBox
  @moduledoc"""
   Integer counter based on an ordered list of counter events.

   A counter is stored as an orddcit of counter events. Each counter
   event has a unique key based on the timestamp and some entropy, and it
   stores the delta from the inc operation. The value of a counter is the
   sum of all these deltas.

   As an optimization, counter events older than a given age are coalesced
   to a single counter event with a key in the form of {timestamp(), 'acc'}
  """

  @type op :: EStateBox.op()
  @type timestamp() :: EStatebox.Clock.timestamp()
  @type timedelta() :: EStateBox.timedelta()
  ## 是一个integer 或者是一个:acc
  @type counter_id() :: EStatebox.Identity.entropy() | :acc
  ## counter_key 是一个时间戳加counter_id 的元组
  @type counter_key() :: {timestamp(), counter_id()}
  ## counter_op 是一个counter_key 和 integer(value) 的集合,
  #当 counter_key 的 counter_id 是一个:acc 时， 表示当前"所有操作"的结果的结果是 Integer ,
  #如果 counter_key 的 counter_id 是一个integer， 那么表示"本次操作"操作的参数是一个integer
  @type counter_op() :: {counter_key(), integer()}
  ## counter 是 counter_op 的集合
  @type counter() :: [counter_op()]

  #计算counter 的值
  @doc """
  Return the value of the counter (the sum of all counter event deltas).
  """
  @spec value(counter) :: Integer
  def value([]), do: 0
  def value([{_key, v} | rest]), do: v + value(rest)

  @doc """
  Merge the given list of counters and return a new counter
  with the union of that history.
  """
  @spec merge([counter]) :: counter
  def merge([counter]), do: counter
  def merge(counters), do: :orddict.from_list(merge_prune(counters))

  @doc """
  Accumulate all counter events older than Timestamp to
  the key {timestamp, acc}, if there is already an ‘acc’
  at or before timestamp this is a no_op.
  """
  ## 累计timestamp之前的所有"counter events" , 然后把计算结果以 key{timestamp, :acc}的方式存放回去
  #如果已近存在:acc, 并且要计算的事件时间小于":acc"事件的时间，则直接返回，不用计算，
  #否则从0开始累计。
  @spec accumulate(timestamp, counter) :: counter
  def accumulate(timestamp, counter = [{{t0, :acc}, _} | _]) when timestamp <= t0, do: counter
  def accumulate(timestamp, counter), do: accumulate(timestamp, counter, 0)

  @doc """
  Return a new counter with the given counter event, If there is an ":acc" at or before the
  timestamp of the given key then this is a a no-op
  """
  @spec inc(counter_key, Integer, counter) ::  counter
  def inc({t1, _}, _, counter = [{{t0, :acc}, _} | _]) when t1 <= t0, do: counter
  def inc(key, value, counter), do: :orddict.store(key, value, counter)

  @doc """
  equive f_inc_acc(value, age, {EStateBox.CLock.timestamp, EStateBox.Identity.entropy})
  """
  @spec f_inc_acc(Integer, timedelta) :: op
  def f_inc_acc(value, age) do
    key = {EStateBox.Clock.timestamp, EStateBox.Identity.entropy}
    f_inc_acc(value, age, key)
  end

  @doc """
  Retuen a "StateBox Event" to increment and accumulate the counter .
  "value" is the delta,
  "age" is the maximum age of counter events in milliseconds
  (this should be longer than the amount of time you expect your cluster to
  reach a consistent state),
  "key" is the counter event key
  """
  @spec f_inc_acc(Integer, timedelta, counter_key) :: op
  def f_inc_acc(value, age, key = {timestamp, _id}), do: {&__MODULE__.op_inc_acc/4, [timestamp - age, key, value]}

  def op_inc_acc(timestamp, key, value, counter) do
    ## 把{key, v} 叠加到counyer中去，然后计算timestamp之前的值
    inc = inc(key, value, counter)
    accumulate(timestamp, inc)
  end
  ## Internal API
  defp merge_prune(counters) do
    ## Merge of all of the counters adn prune all entries older than the newst{_, :acc}
    prune(:lists.umerge(counters))
  end

  def prune(all), do: prune(all, all)
  def prune(here = [{{_ts, :acc}, _v} | rest], _last), do: prune(rest, here)
  def prune([_ | rest], last), do: prune(rest, last)
  def prune([], last), do: last

  ## 累计"老事件"， 如果计算到某一个事件是:acc，那么在:acc之前的事件就不用再累计了
  ## Roll up old counter events
  defp accumulate(timestamp, [{{t1, _id}, value} | rest], sum) when t1 <= timestamp, do: accumulate(timestamp, rest, value + sum)
  ## Return the new counter
  defp accumulate(timestamp, counter, sum), do: inc({timestamp, :acc}, sum, counter)
end
