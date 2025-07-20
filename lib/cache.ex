defmodule Cache do
  @moduledoc """
  Caching interface for storing/retrieving Scryfall cards.
  """

  @type key :: binary()
  @type value :: map()
  @type ttl :: non_neg_integer()  # seconds

  @callback get(key) :: {:ok, value} | :miss
  @callback put(key, value, ttl) :: :ok
end

