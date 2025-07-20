defmodule Cache.InMemory do
  @behaviour Cache

  use GenServer
  @table :scryfall_cache
  @ttl 7 * 24 * 60 * 60  # 7 days, in seconds

  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def get(key) when is_binary(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, inserted_at}] ->
        if recent?(inserted_at) do
          {:ok, value}
        else
          :ets.delete(@table, key)
          :miss
        end

      _ -> :miss
    end
  end

  @impl true
  def put(key, value, _ttl \\ @ttl) when is_binary(key) do
    :ets.insert(@table, {key, value, current_timestamp()})
    :ok
  end

  # Private

  defp recent?(timestamp) do
    now = current_timestamp()
    now - timestamp <= @ttl
  end

  defp current_timestamp(), do: :os.system_time(:second)

  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, 60_000 * 60)  # hourly
  end

  @impl true
  def handle_info(:cleanup, state) do
    now_ts = current_timestamp()

    :ets.tab2list(@table)
    |> Enum.each(fn {key, _val, ts} ->
      if now_ts - ts > @ttl, do: :ets.delete(@table, key)
    end)

    schedule_cleanup()
    {:noreply, state}
  end
end

