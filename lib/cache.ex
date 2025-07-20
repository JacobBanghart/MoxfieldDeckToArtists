defmodule Cache do
  @moduledoc """
  Caching interface for storing/retrieving Scryfall cards.
  """

  @type key :: binary()
  @type value :: map()
  @callback get(key) :: {:ok, value} | :miss
  @callback put(key, value) :: :ok
end
