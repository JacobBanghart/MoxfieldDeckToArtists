defmodule GetUniqueArtists do
  @scryfall_url "https://api.scryfall.com/cards/collection"

  # ✅ Entry point for web/server:
  def get_artists(moxfield_url) do
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

  # ✅ CLI entry point (same as before)
  def run([moxfield_url]) do
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

  def run(_), do:
    IO.puts("❌ Usage: elixir get_unique_artists.exs https://www.moxfield.com/decks/<deck-id>")

  # 🧩 Deck ID parser
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

  # 🌐 Moxfield fetch
  defp fetch_deck(deck_id) do
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
        {:error, "Moxfield error (#{status})"}

      {:error, reason} ->
        {:error, "Deck fetch failed: #{inspect(reason)}"}
    end
  end

  # 🔍 Parse Scryfall IDs
  defp get_scryfall_ids(deck) do
    cards = get_in(deck, ["boards", "mainboard", "cards"]) || %{}

    cards
    |> Map.values()
    |> Enum.map(&get_in(&1, ["card", "scryfall_id"]))
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  # 🎴 Scryfall API batching
  defp fetch_artists_bulk(ids), do: fetch_batches(ids, 75, MapSet.new()) |> MapSet.to_list()

  defp fetch_batches([], _batch_size, acc), do: acc

  defp fetch_batches(ids, batch_size, acc) do
    {batch, rest} = Enum.split(ids, batch_size)

    IO.puts("🎴 Fetching batch: #{length(batch)} cards...")

    body = Jason.encode!(%{
      "identifiers" => Enum.map(batch, fn id -> %{"id" => id} end)
    })

    case HTTPoison.post(@scryfall_url, body, [{"Content-Type", "application/json"}], recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => cards, "not_found" => not_found}} ->
            if Enum.any?(not_found), do: IO.warn("⚠️ Not found: #{inspect(not_found)}")
            new_acc = Enum.reduce(cards, acc, &extract_artists(&1, &2))
            fetch_batches(rest, batch_size, new_acc)

          {:ok, %{"data" => cards}} ->
            new_acc = Enum.reduce(cards, acc, &extract_artists(&1, &2))
            fetch_batches(rest, batch_size, new_acc)

          _ ->
            IO.warn("⚠️ Failed to decode Scryfall response")
            fetch_batches(rest, batch_size, acc)
        end

      {:ok, %{status_code: code, body: body}} ->
        IO.warn("⚠️ Batch failed with status #{code}: #{body}")
        fetch_batches(rest, batch_size, acc)

      {:error, reason} ->
        IO.warn("❌ HTTP error: #{inspect(reason)}")
        fetch_batches(rest, batch_size, acc)
    end
  end

  # 🎨 Artist parsing
  defp extract_artists(card, acc) do
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
end

