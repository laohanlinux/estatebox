defmodule EStateBox.Clock do
  @moduledoc """
   this is !!!!!!!!!!!
  """
  @vsn 0.1

  @doc """
    Current UNIX epoch timestamp in integer milliseconds,
    Equivalient to <code> now_to_msec(os:timestam()) </code>
  """

  @spec timestamp() :: (integer)
  def timestamp do
    now_to_msec(:os.timestamp())
  end

  @doc """
    Converts given time of now(0 format to UNIX epoch timestamp in integer milliseconds)
  """
  @spec now_to_msec(tuple) :: (integer)
  @kilo 1000
  @mega 1000000
  def now_to_msec({megaSecs, secs, microSecs}) do
    :erlang.trunc(((megaSecs * @mega) + secs + (microSecs / @mega)) * @kilo)
  end

  @spec now() :: (tuple)
  def now, do: :erlang.now()

end
