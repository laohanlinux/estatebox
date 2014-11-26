defmodule EStateBox.Orddict do
  require EStateBox
  @type proplist :: [{term(), term()}]
  @type orddict :: proplist()
  @type statebox :: EStateBox.statebox
  @type op :: EStateBox.op

  @doc"""
  Return a statebox() from a list of statebox() and/or proplist().
     proplist() are convered to a new statebox() with f_merge_proplist/2
     before merge.

  """
  @spec from_values([proplist() | statebox()]) :: statebox()

  def from_values([]), do: EStateBox.new(fn() -> [] end)
  def from_values(vals) do
    Enum.reduce(vals, [], fn(v, acc) -> as_statebox(v) end) |> EStateBox.merge
  end

  @doc"""
    Convert a proplist() to an orddict().
    Only [{term(), term()}] proplists are supported.
  """
  @spec orddict_from_proplist(proplist()) :: orddict()
  def orddict_from_proplist(p), do: :orddict.from_list(p)

  @doc"""
    Return true if the statebox's value is [], false otherwise
  """
  @spec is_empty(statebox()) :: boolean()
  def is_empty(box), do: EStateBox.value(box) == []

  @doc"""
    Returns an op() that does an ordsets:union(New, Set) on the value at
    K in orddict (or [] if not present).
  """
  @spec f_union(term(), [term()]) :: op()
  def f_union(k, new), do: {&__MODULE__.op_union/3, [k, new]}

  @doc"""
    Returns an op() that does an ordsets:subtract(Set, Del) on the value at
    K in orddict (or [] if not present).
  """
  @spec f_subtract(term(), [term()]) :: op()
  def f_subtract(k, del), do: {&__MODULE__.op_subtract/3, [k, del]}

  @doc"""
    Returns an op() that merges the proplist New to the orddict.
  """
  @spec f_merge_proplist(term()) :: op()
  def f_merge_proplist(new), do: f_merge(orddict_from_proplist(new))

  @doc"""
    Returns an op() that merges the orddict New to the orddict.
  """
  @spec f_merge(term()) :: op()
  def f_merge(new), do: {&__MODULE__.op_merge/2, [new]}

  @doc"""
    Returns an op() that updates the value at Key in orddict (or [] if
    not present) with the given Op.
  """
  @spec f_update(term(), op()) :: op()
  def f_update(key, op), do: {&__MODULE__.op_update/3, [key, op]}

  @doc"""
    Returns an op() that stores Value at Key in orddict.
  """
  @spec f_store(term(), term()) :: op()
  def f_store(key, value), do: {:orddict.store/3, [key, value]}

  @doc"""
    Returns an op() that deletes the pair if present from orddict.
  """
  @spec f_delete({term(), term()}) :: op()
  def f_delete(pair={_, _}), do: {:lists.delete/2, [pair]}
  @doc"""
    Returns an op() that erases the value at K in orddict.
  """
  @spec f_erase(term()) :: op()
  def f_erase(key), do: {:orddict.erase/2, [key]}

  #Statebox ops
  defp op_union(k, new, d), do: :orddict.update(k, fn(old) -> :ordsets.union(old, new) end, new, d)

  defp op_subtract(k, del, d), do: :orddict.update(k, fn(old) -> :ordsets.subtract(old, del) end, [], d)

  defp op_merge(new, d), do: :orddict.merge(fn(_Key, _OldV, newv) -> newv end, d, new)

  # This is very similar to orddict.update/4
  defp op_update(key, op, [{k, _}=e | dict]) when key < k, do: [{key, EStateBox.apply_op(op, [])}, e | dict]
  defp op_update(key, op, [{k, _}=e | dict]) when key > k, do: [e | op_update(Key, op, dict)]
  defp op_update(key, op, [{_k, val} | dict]) , do: [{key, EStateBox.apply_op(op, val)} | dict]
  defp op_update(key, op, []), do: [{key, EStateBox.apply_op(op, [])}]

  #Internal API
  defp as_statebox(v) do
    case EStateBox.is_statebox(v) do
        true ->
            v
        false ->
            from_legacy(v)
    end
  end

  defp from_legacy(d) do
    #Legacy objects should always be overwritten.
    EStateBox.modify(f_merge_proplist(d), EStateBox.new(fn () -> [] end))
  end

end
