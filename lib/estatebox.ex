defmodule EStateBox do
  require EStateBox.Clock
  @moduledoc """
  A monad for wrapping a value with a ordered event queue such that values that have diverged in history can be merged automatically in a predictable manner.
  In order to provide for an efficient serialization, old events can be expired with expire/2 and the event queue can be truncated to a specific maximum size with truncate/2.
  The default representation for a timestamp is OS clock msecs, defined by <code>statebox_clock:timestamp/0</code>.
  This is used by the convenience functions <code>new/1</code> and <code>modify/2</code>.
  """
  @opaque statebox() :: StateBox
  @type event() :: {timestamp(), op()}
  @type timestamp() :: EStateBox.Clock.timestamp()
  @type timedelta() :: integer()
  @type basic_op() :: {module(), atom(), [term()]} |
                      # function type
                      {((term(), term()) -> StateBox) |
                      ((term(), term(), term()) -> StateBox), [term()]}
  @type op() :: basic_op() | [op()]
  defmodule StateBox do defstruct [
    value: nil,
    ##  sorted list of operations (oldest first)
    queue: [],
    last_modified: EStateBox.Clock.timestamp()]
  end

  @doc """
  Return true if the argument is a statebox, false otherwise
  """
  def is_statebox(%StateBox{}), do: true
  def is_statebox(_), do: false

  @doc """
  Construct a statebox at <code>statebox_clock:timestamp()</code>
      containing the result of <code>Constructor()</code>. This should
      return an "empty" object of the desired type, such as
      <code>fun gb_trees:empty/0</code>.
  """
  #@spec new((() :: term())) :: StateBox
  def new(constructor), do: new(EStateBox.Clock.timestamp(), constructor)
  @doc """
  Construct a statebox at statebox_clock.timestamp,
  containing the result of Constructor().
  This should return an "empty" object if the desired type, such as fun fun gb_trees:empty/0
  """
  #@spec new((() :: term()))  :: StateBox
  def new(t, constructor), do: new(t, constructor.(), [])

  @doc """
  Return the current value of the StateBox. You Should consider this value to be read-only
  """
  @spec value(StateBox) :: term()
  def value(%StateBox{value: value}), do: value

  @doc"""
  Return the last modified timestamp of the StateBox
  """
  @spec last_modified(StateBox) :: EStateBox.Clock.timestamp
  def last_modified(%StateBox{last_modified: t}), do: t

  @doc """
  Remove all events older than last_modified(s) - age from the event queue,
  queue type is [event()], event is {timestamp, op()}
  """
  @spec expire(integer, StateBox) :: StateBox
  def expire(age, state = %StateBox{queue: q, last_modified: t}) do
    oldt = t - age
    q = q |> Enum.filter(fn({eventt, _}) -> eventt >= oldt end)
    %{state | queue: q}
  end

  @doc """
  truncate the event queue to the newest N events
  eg:
  [1, 2 , 3, 4] --1--> [2, 3, 4]
  """
  @spec truncate(integer, StateBox) :: StateBox
  def truncate(n, state = %StateBox{queue: q}) do
    case :erlang.length(q) -n do
      tail when tail >0 ->
        %{state | queue: :lists.nthtail(tail, q)}
      _ ->
        state
    end
  end
  @doc """
  Return a new statebox as the product of all in-order events appliedd to
  the last modified statebox(). if two events occur at the same time, the
  event that sorts lowest by value will be applied first.
  """
  @spec merge([StateBox]) :: StateBox
  def merge([state]), do: state
  def merge(unordered) do
    %StateBox{value: v, last_modified: t} = newest(unordered)
    queue = unordered |>
      Enum.map(fn(%StateBox{queue: q}) -> q end) |>
      :lists.umerge
    new(t, apply_queue(v, queue), queue)
  end

  @doc """
  Modify the value in statebox and add {T, Op} to its event queue.
  Op should be a <code>{M, F, Args}</code> or <code>{Fun, Args}</code>.
  The value will be transformed as such:
  <code>NewValue = apply(Fun, Args ++ [value(S)])</code>.
  The operation should be repeatable and should return the same type as
  <code>value(S)</code>. This means that this should hold true:
  <code>Fun(Arg, S) =:= Fun(Arg, Fun(Arg, S))</code>.
  An example of this kind of operation is <code>orddict:store/3</code>.
  Only exported operations should be used in order to ensure that the
  serialization is small and robust (this is not enforced).
  """
  @spec modify(EStateBox.Clock.timestamp, term, StateBox) :: StateBox
  def modify(t, op, %StateBox{value: value, queue: queue, last_modified: oldt}) when oldt <= t do
    new(t, apply_op(op, value), queue_in({t, op}, queue))
  end
  def modify(t, _op, %StateBox{last_modified: oldt}), do: throw({:invalid_timestamp, {t, '<',  oldt}})

  @doc """
  Modify a statebox at timestamp
    max(1 + last_modified(s)), EStateBox.Clock.timestamp());
    see modify/3 for more information
    modify(max(1 + last_modified(s), EStateBox.Clock.timestamp()), op, s)
  """
  @spec modify(term, StateBox) :: StateBox
  def modify(op, s), do: modify(max(1 + last_modified(s), EStateBox.Clock.timestamp()), op, s)

  @doc """
  Apply an op() to data
  op :: func, arguments
  this is a key/value structure
  """
  @spec apply_op(term, term) :: term
  def apply_op({f, [a]}, data) when is_function(f, 2), do: f.(a, data)
  def apply_op({f, [a, b]}, data) when is_function(f, 3), do: f.(a, b, data)
  def apply_op({f, [a, b, c]}, data) when is_function(f, 4), do: f.(a, b, c, data)
  ##
  def apply_op({f, a}, data) when is_function(f), do: apply(f, a ++ [ data ])

  def apply_op({m, f, [a]}, data), do: apply(m, f, [a, data])
  def apply_op({m, f, [a, b]}, data), do: apply(m, f, [a, b, data])

  def apply_op({m, f, a}, data), do: apply(m ,f, a ++ [data])

  ## it can been used on queue withoud timestamp, eg: [op(), op(), op()]
  #really, it should be [event(), event()]
  def apply_op([op | rest], data), do: apply_op(rest, apply_op(op, data))
  def apply_op([], data), do: data
  ## Internal API

  @spec newest(list) :: EStateBox
  defp newest([first | rest]), do: newest(first, rest)
  defp newest(m0, [m1 | rest]) do
    case last_modified(m0) >= last_modified(m1) do
      true ->
        newest(m0, rest)
      false ->
        newest(m1, rest)
    end
  end
  defp newest(m, []), do: m
  ## Return a new StateBox
  defp new(t, v, q) do
    %StateBox{value: v, queue: q, last_modified: t}
  end
  ## Push a new into event queue
  defp queue_in(event, queue), do: queue ++ [event]

  ## operation on every event of queue
  defp apply_queue(data, [{_t, op} | rest]), do: apply_queue(apply_op(op, data), rest)
  defp apply_queue(data, []), do: data

end
