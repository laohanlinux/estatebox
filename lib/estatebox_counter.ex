defmodule EStateBox.Counter do

  @moduledoc"""
   Integer counter based on an ordered list of counter events.

   A counter is stored as an orddcit of counter events. Each counter
   event has a unique key based on the timestamp and some entropy, and it
   stores the delta from the inc operation. The value of a counter is the
   sum of all these deltas.

   As an optimization, counter events older than a given age are coalesced
   to a single counter event with a key in the form of {timestamp(), 'acc'}
  """
#-type op() :: statebox:op().
#-type timestamp() :: statebox_clock:timestamp().
#-type timedelta() :: statebox:timedelta().
#-type counter_id() :: statebox_identity:entropy() | acc.
#-type counter_key() :: {timestamp(), counter_id()}.
#-type counter_op() :: {counter_key(), integer()}.
#-type counter() :: [counter_op()].
  def value([]), do: 0
  def value([{_key, v} | rest]), do: v + value(rest)

  @doc """
  Merge the given list of counters and return a new counter
  with the union of that history.
  """
  def merge([counter]), do: counter
  def merge(counters), do: :orddict.for_list(merge_prune(counters))

  @doc """
  Accumulate all counter events older than Timestamp to
  the key {timestamp, acc}, if there is already an ‘acc’
  at or before timestamp this is a no_op.
  """
  def accumulate(timestamp, counter = [{{t0, :acc}, _} | _]) when timestamp <= t0, do: counter
  def accumulate(timestamp, counter), do: accumulate(timestamp, counter, 0)

end
