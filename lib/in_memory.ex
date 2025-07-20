defmodule Cache.InMemory do
  @behaviour Cache

  use GenServer
  @table :scryfall_cache
  # 7 days, in seconds
  @ttl 7 * 24 * 60 * 60

  @moduledoc """
  Cache.InMemory

  An in-memory cache using ETS and GenServer for storing Scryfall card data with TTL and periodic cleanup.
  """

  # Public API
  @doc """
  Starts the cache GenServer and ETS table.
  """
  @spec start_link(any()) :: {:ok, pid()} | {:error, any()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  @doc """
  Initializes the ETS table and starts the cleanup timer.
  """
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    start_cleanup_timer()
    {:ok, %{}}
  end

  @impl true
  @doc """
  Gets a value from the cache if present and not expired.
  Returns {:ok, value} or :miss.
  """
  @spec get(binary()) :: {:ok, any()} | :miss
  def get(key) when is_binary(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, inserted_at}] ->
        if recent?(inserted_at) do
          {:ok, value}
        else
          :ets.delete(@table, key)
          :miss
        end

      _ ->
        :miss
    end
  end

  @impl true
  @doc """
  Puts a value in the cache with the current timestamp.
  """
  @spec put(binary(), any()) :: :ok
  def put(key, value) when is_binary(key) do
    :ets.insert(@table, {key, value, current_timestamp()})
    :ok
  end

  # Private

  defp recent?(timestamp) when is_integer(timestamp) do
    now = current_timestamp()
    now - timestamp <= @ttl
  end

  defp current_timestamp(), do: :os.system_time(:second)

  defp start_cleanup_timer() do
    # hourly
    Process.send_after(self(), :cleanup, 60_000 * 60)
  end

  @impl true
  @doc """
  Handles periodic cleanup of expired cache entries.
  """
  def handle_info(:cleanup, _state) do
    now_ts = current_timestamp()

    :ets.tab2list(@table)
    |> Enum.each(fn {key, _val, ts} ->
      if now_ts - ts > @ttl, do: :ets.delete(@table, key)
    end)

    start_cleanup_timer()
    :ok
  end
end
