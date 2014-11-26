defmodule EStateBox.Identity do
  require EStateBox.Clock
  @moduledoc """
    hello word!!!
  """
  @vsn 0.1
  @doc"""
    equive entropy(node(), EStatebox.Clock.now())
  """
  @spec entropy() :: (tuple)
  def entropy, do: entropy(:erlang.node(), EStateBox.Clock.now())
  def entropy(node, now), do: :erlang.phash2({node, now})

end
