defmodule EStateBox do
  require EStateBox.Clock
  @moduledoc """
  A monad for wrapping a value with a ordered event queue such that values that have diverged in history can be merged automatically in a predictable manner.
  In order to provide for an efficient serialization, old events can be expired with expire/2 and the event queue can be truncated to a specific maximum size with truncate/2.
  The default representation for a timestamp is OS clock msecs, defined by <code>statebox_clock:timestamp/0</code>.
  This is used by the convenience functions <code>new/1</code> and <code>modify/2</code>.
  """
 # @opaque statebox() :: StateBox
  #@type event() :: {timestamp(), op()}
  #@deftype timestamp() :: EStateBox.Clock.timestamp()
  #@type timedelta() :: integer()
  #@type basic_op() :: {module(), atom(), [term()]} |
                      ## function type
                      #{((term(), term()) -> StateBox) |
                      #((term(), term(), term()) -> StateBox), [term()]}
  #@type op() :: basic_op() | [op()]
  defmodule StateBox do defstruct [
    value: nil,
    ##  sorted list of operations (oldest first)
    queue: [],
    last_modified: EStateBox.timestamp]
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
  @spec new(fun(() :: term())) :: StateBox
  def new(constructor), do: new(EStateBox.Clock.timestamp(), constructor)
  @doc """
  Construct a statebox at statebox_clock.timestamp,
  containing the result of Constructor().
  This should return an "empty" object if the desired type, such as fun fun gb_trees:empty/0
  """
  @spec new(fun(() :: term()))  :: StateBox
  def new(t, constructor), do: new(t, constructor(), [])

  @doc """
  Return the current value of the StateBox. You Should consider this value to be read-only
  """
  @spec value(StateBox) :: term()
  def value(%StateBox{value: value}), do: value

  @doc"""
  Return the last modified timestamp of the StateBox
  """
  @spec last_modified(StateBox) :: EStateBox.timestamp
  def last_modified(%StateBox{last_modified: t}), do: t

  @doc """
  Remove all events older than last_modified(s) - age from the event queue,
  queue type is [event()], event is {timestamp, op()}
  """
  @spec expire(integer, StateBox) :: StateBox
  def expire(age, state = %StateBox{queue: q, last_modified: t}) do
    oldt = t - age
    q = q |> Enum.filter(fn({eventt, _}) -> eventt < oldt end)
    %StateBox{queue: q} = state
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
        %StateBox{queue: :lists.nthtail(tail, q)} = state
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

  end

end
