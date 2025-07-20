defmodule GetUniqueArtists do
  @scryfall_url "https://api.scryfall.com/cards/collection"
  @cache Cache.InMemory
  @batch_size 75
  @cache_ttl 7 * 24 * 60 * 60 # 7 days in seconds

  ##########################################
  # ✅ Public Entrypoints
  ##########################################

  def get_artists(moxfield_url) do
    IO.puts("🔗 Extracting deck ID from #{moxfield_url}")
    with {:ok, deck_id} <- extract_deck_id(moxfield_url),
         {:ok, deck} <- fetch_deck(deck_id),
         card_ids when is_list(card_ids) <- get_scryfall_ids(deck),
         artists when is_list(artists) <- fetch_artists_bulk(card_ids) do
      {:ok, artists}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, "Invalid Moxfield URL"}
      _ -> {:error, "Unexpected error occurred"}
    end
  end

  def run([moxfield_url]) do
    start_cache()

    case get_artists(moxfield_url) do
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

  defp extract_deck_id(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) ->
        path
        |> String.split("/")
        |> Enum.drop_while(&(&1 != "decks"))
        |> Enum.at(1)
        |> case do
          nil -> {:error, "No deck ID found"}
          id -> {:ok, id}
        end

      _ -> {:error, "Invalid URL"}
    end
  end

  defp fetch_deck(deck_id) do
    IO.puts("📦 Fetching deck https://api2.moxfield.com/v3/decks/all/#{deck_id}")
    url = "https://api2.moxfield.com/v3/decks/all/#{deck_id}"
    headers = [
      {"Accept", "application/json"},
      {"User-Agent", "Elixir HTTP Client"}
    ]

    case HTTPoison.get(url, headers, follow_redirect: true) do
      {:ok, %{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %{status_code: status, body: body}} ->
        IO.warn("⚠️ HTTP error: status #{status}, body: #{body}")
        {:error, "Deck fetch failed"}

      {:error, reason} ->
        {:error, "Deck fetch failed: #{inspect(reason)}"}
    end
  end

  ##########################################
  # 🧠 Card & Artist Logic
  ##########################################

  defp get_scryfall_ids(deck) do
    cards = get_in(deck, ["boards", "mainboard", "cards"]) || %{}

    cards
    |> Map.values()
    |> Enum.map(&get_in(&1, ["card", "scryfall_id"]))
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  defp fetch_artists_bulk(ids) do
    start_cache()
    ids
    |> Stream.chunk_every(@batch_size)
    |> Enum.reduce(MapSet.new(), &fetch_chunk/2)
    |> MapSet.to_list()
  end

  defp fetch_chunk(batch_ids, acc) do
    {cached, to_fetch} =
      Enum.split_with(batch_ids, fn id ->
        case @cache.get(id) do
          {:ok, _card} -> true
          :miss -> false
        end
      end)

    acc =
      Enum.reduce(cached, acc, fn id, acc ->
        {:ok, card} = @cache.get(id)
        extract_artists(card, acc)
      end)

    if to_fetch == [] do
      acc
    else
      IO.puts("🎴 Fetching #{length(to_fetch)} cards from Scryfall...")

      body = Jason.encode!(%{
        "identifiers" => Enum.map(to_fetch, &%{"id" => &1})
      })

      case HTTPoison.post(@scryfall_url, body, [{"Content-Type", "application/json"}], recv_timeout: 30_000) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"data" => cards, "not_found" => not_found}} ->
              if Enum.any?(not_found), do: IO.warn("⚠️ Not found: #{inspect(not_found)}")
              cache_all(cards)
              Enum.reduce(cards, acc, &extract_artists(&1, &2))

            {:ok, %{"data" => cards}} ->
              cache_all(cards)
              Enum.reduce(cards, acc, &extract_artists(&1, &2))

            _ ->
              IO.warn("⚠️ Failed to parse Scryfall response")
              acc
          end

        {:ok, %{status_code: code, body: body}} ->
          IO.warn("⚠️ Scryfall request failed with status #{code}: #{body}")
          acc

        {:error, reason} ->
          IO.warn("❌ HTTP error: #{inspect(reason)}")
          acc
      end
    end
  end

  defp cache_all(cards) do
    Enum.each(cards, fn %{"id" => id} = card ->
      @cache.put(id, card, @cache_ttl)
    end)
  end

  defp extract_artists(%{} = card, acc) do
    acc
    |> maybe_add(card["artist"])
    |> maybe_add_faces(card["card_faces"] || [])
  end

  defp maybe_add(set, artist) when is_binary(artist),
    do: MapSet.put(set, String.trim(artist))

  defp maybe_add(set, _), do: set

  defp maybe_add_faces(set, faces) do
    Enum.reduce(faces, set, fn face, acc ->
      maybe_add(acc, face["artist"])
    end)
  end

  defp start_cache do
    unless Process.whereis(@cache), do: @cache.start_link([])
  end
end

