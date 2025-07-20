defmodule GetUniqueArtistsTest do
  use ExUnit.Case

  describe "extract_deck_id/1" do
    test "extracts deck id from valid moxfield url" do
      url = "https://www.moxfield.com/decks/abc123"
      assert GetUniqueArtists.extract_deck_id(url) == {:ok, "abc123"}
    end

    test "returns error for url without deck id" do
      url = "https://www.moxfield.com/decks/"
      assert GetUniqueArtists.extract_deck_id(url) == {:error, "No deck ID found"}
    end

    test "returns error for invalid url" do
      url = "not a url"
      assert GetUniqueArtists.extract_deck_id(url) == {:error, "Invalid URL"}
    end
  end

  describe "get_scryfall_card_ids/1" do
    test "returns unique scryfall ids from deck structure" do
      deck = %{
        "boards" => %{
          "mainboard" => %{
            "cards" => %{
              "1" => %{"card" => %{"scryfall_id" => "id1"}},
              "2" => %{"card" => %{"scryfall_id" => "id2"}},
              "3" => %{"card" => %{"scryfall_id" => "id1"}}
            }
          }
        }
      }

      assert GetUniqueArtists.get_scryfall_card_ids(deck) == ["id1", "id2"]
    end

    test "returns empty list if no cards" do
      deck = %{"boards" => %{"mainboard" => %{"cards" => %{}}}}
      assert GetUniqueArtists.get_scryfall_card_ids(deck) == []
    end
  end
end
