defmodule GetUniqueArtists do
  @moduledoc """
  GetUniqueArtists

  Fetches and lists unique Magic: The Gathering card artists from a Moxfield deck URL using Scryfall API.
  """

  @scryfall_url "https://api.scryfall.com/cards/collection"
  @cache Cache.InMemory
  @batch_size 75

  ##########################################
  # ✅ Public Entrypoints
  ##########################################

  @doc """
  Given a Moxfield deck URL, returns {:ok, artists} with a list of unique artist names, or {:error, reason}.
  Handles all error cases explicitly.
  """
  def get_unique_artists(moxfield_url) do
    IO.puts("🔗 Extracting deck ID from #{moxfield_url}")

    with {:ok, deck_id} <- extract_deck_id(moxfield_url),
         {:ok, deck} <- fetch_deck_from_api(deck_id),
         card_ids when is_list(card_ids) <- get_scryfall_card_ids(deck),
         artists when is_list(artists) <- get_artists_from_scryfall(card_ids) do
      {:ok, artists}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, "Invalid Moxfield URL"}
      other -> {:error, inspect(other)}
    end
  end

  @doc """
  Runs the CLI entrypoint for fetching and printing unique artists from a Moxfield deck URL.
  """
  def run([moxfield_url]) do
    init_cache()

    case get_unique_artists(moxfield_url) do
      {:ok, artists} ->
        IO.puts("\n🎨 Unique Artists (#{length(artists)} total):\n")

        artists
        |> Enum.sort()
        |> Enum.with_index(1)
        |> Enum.each(fn {artist, i} ->
          IO.puts("#{String.pad_leading(Integer.to_string(i), 2, "0")}. #{artist}")
        end)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
    end
  end

  ##########################################
  # 🔗 URL & Deck Fetching
  ##########################################

  @doc """
  Extracts the deck ID from a Moxfield deck URL.
  Returns {:ok, deck_id} or {:error, reason}.
  """
  def extract_deck_id(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) ->
        if String.contains?(path, "/decks/") do
          parts =
            path
            |> String.split("/")
            |> Enum.drop_while(&(&1 != "decks"))
            |> Enum.at(1)

          case parts do
            nil -> {:error, "No deck ID found"}
            "" -> {:error, "No deck ID found"}
            id -> {:ok, id}
          end
        else
          {:error, "Invalid URL"}
        end

      _ ->
        {:error, "Invalid URL"}
    end
  end

  @doc """
  Fetches deck data from the Moxfield API given a deck ID.
  Returns {:ok, deck} or {:error, reason}. Handles JSON decode errors.
  """
  def fetch_deck_from_api(deck_id) do
    IO.puts("📦 Fetching deck https://api2.moxfield.com/v3/decks/all/#{deck_id}")
    url = "https://api2.moxfield.com/v3/decks/all/#{deck_id}"

    headers = [
      {"Accept", "application/json"},
      {"User-Agent", "Elixir HTTP Client"}
    ]

    case HTTPoison.get(url, headers, follow_redirect: true) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, deck} ->
            {:ok, deck}

          {:error, decode_error} ->
            IO.warn("⚠️ JSON decode error: #{inspect(decode_error)}")
            {:error, "Deck JSON decode failed"}
        end

      {:ok, %{status_code: status, body: body}} ->
        IO.warn("⚠️ HTTP error: status #{status}, body: #{body}")
        {:error, "Deck fetch failed"}

      {:error, reason} ->
        IO.warn("❌ HTTP error: #{inspect(reason)}")
        {:error, "Deck fetch failed: #{inspect(reason)}"}
    end
  end

  ##########################################
  # 🧠 Card & Artist Logic
  ##########################################

  @doc """
  Extracts unique Scryfall card IDs from a deck data structure.
  """
  def get_scryfall_card_ids(deck) do
    cards = get_in(deck, ["boards", "mainboard", "cards"]) || %{}

    cards
    |> Map.values()
    |> Enum.map(&get_in(&1, ["card", "scryfall_id"]))
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  @doc """
  Fetches and returns a list of unique artists from Scryfall given a list of card IDs.
  Uses parallel batch fetching for speed.
  """
  def get_artists_from_scryfall(ids) do
    init_cache()

    ids
    |> Stream.chunk_every(@batch_size)
    |> Task.async_stream(&fetch_scryfall_batch(&1, MapSet.new()), max_concurrency: 4, timeout: 60_000)
    |> Enum.reduce(MapSet.new(), fn
      {:ok, set}, acc -> MapSet.union(acc, set)
      {:exit, _}, acc -> acc
    end)
    |> MapSet.to_list()
  end

  @doc """
  Fetches a batch of cards from Scryfall and adds their artists to the accumulator set.
  Handles all error cases explicitly.
  Optimized to avoid redundant cache gets.
  """
  def fetch_scryfall_batch(batch_ids, acc) do
    # Only call @cache.get/1 once per id
    {cached, to_fetch} =
      Enum.reduce(batch_ids, {[], []}, fn id, {cached, to_fetch} ->
        case @cache.get(id) do
          {:ok, card} -> {[{id, card} | cached], to_fetch}
          :miss -> {cached, [id | to_fetch]}
        end
      end)

    acc =
      Enum.reduce(cached, acc, fn {_id, card}, acc ->
        add_artists_to_set(card, acc)
      end)

    if to_fetch == [] do
      acc
    else
      IO.puts("🎴 Fetching #{length(to_fetch)} cards from Scryfall...")

      body =
        Jason.encode!(%{
          "identifiers" => Enum.map(to_fetch, &%{"id" => &1})
        })

      case HTTPoison.post(@scryfall_url, body, [{"Content-Type", "application/json"}],
             recv_timeout: 30_000
           ) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"data" => cards, "not_found" => not_found}} ->
              if Enum.any?(not_found), do: IO.warn("⚠️ Not found: #{inspect(not_found)}")
              cache_scryfall_cards(cards)
              Enum.reduce(cards, acc, &add_artists_to_set(&1, &2))

            {:ok, %{"data" => cards}} ->
              cache_scryfall_cards(cards)
              Enum.reduce(cards, acc, &add_artists_to_set(&1, &2))

            {:error, decode_error} ->
              IO.warn("⚠️ Scryfall JSON decode error: #{inspect(decode_error)}")
              acc

            other ->
              IO.warn("⚠️ Unexpected Scryfall response: #{inspect(other)}")
              acc
          end

        {:ok, %{status_code: code, body: body}} ->
          IO.warn("⚠️ Scryfall request failed with status #{code}: #{body}")
          acc

        {:error, reason} ->
          IO.warn("❌ Scryfall HTTP error: #{inspect(reason)}")
          acc
      end
    end
  end

  @doc """
  Adds artist(s) from a card to the accumulator set.
  """
  def add_artists_to_set(%{} = card, acc) do
    acc
    |> add_artist(card["artist"])
    |> add_face_artists(card["card_faces"] || [])
  end

  @doc """
  Adds a single artist to the set if present.
  """
  def add_artist(set, artist) when is_binary(artist),
    do: MapSet.put(set, String.trim(artist))

  def add_artist(set, _), do: set

  @doc """
  Adds artists from card faces to the set.
  """
  def add_face_artists(set, faces) do
    Enum.reduce(faces, set, fn face, acc ->
      add_artist(acc, face["artist"])
    end)
  end

  @doc """
  Initializes the cache if not already started.
  """
  def init_cache do
    unless Process.whereis(@cache), do: @cache.start_link([])
  end

  @doc """
  Caches Scryfall card data in ETS.
  """
  def cache_scryfall_cards(cards) do
    Enum.each(cards, fn %{"id" => id} = card ->
      @cache.put(id, card)
    end)
  end
end
