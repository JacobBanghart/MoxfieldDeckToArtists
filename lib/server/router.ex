defmodule GetUniqueArtists.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:urlencoded, :multipart])
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title>🎨 MTG Artists Finder</title>
          <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
        </head>
        <body class="bg-gray-100 min-h-screen flex flex-col justify-center items-center px-4">
          <div class="w-full max-w-lg mt-24 bg-white shadow-xl rounded-lg p-8">
            <h1 class="text-3xl font-bold text-indigo-700 mb-3 flex items-center gap-2">🎨 MTG Unique Artists</h1>
            <p class="mb-6 text-gray-500">Paste your Moxfield deck URL below to view a list of all unique artists in your deck.</p>
            <form method="GET" action="/artists" class="flex flex-col space-y-4">
              <input
                type="text"
                name="url"
                placeholder="https://www.moxfield.com/decks/your-deck-id"
                class="rounded-lg border-2 border-gray-300 px-4 py-3 text-base focus:outline-none focus:border-indigo-600 placeholder-gray-400 transition"
                required
              />
              <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded-lg transition">
                ➡️ Fetch Artists
              </button>
            </form>
          </div>
          <footer class="text-sm mt-6 text-gray-400">Powered by Scryfall &amp; Moxfield</footer>
        </body>
      </html>
    """)
  end

  get "/artists" do
    deck_url = conn.params["url"]

    case GetUniqueArtists.get_unique_artists(deck_url) do
      {:ok, artists} ->
        html = """
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>🎨 MTG Unique Artists</title>
              <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
            </head>
            <body class="bg-gray-100 min-h-screen flex flex-col items-center px-4">
              <div class="w-full max-w-lg mt-16 bg-white shadow-xl rounded-lg p-8">
                <h2 class="text-2xl font-bold text-indigo-700 mb-5">🎨 #{length(artists)} Unique Artists</h2>
                <ul class="divide-y divide-gray-200 mb-6">
                  #{Enum.map_join(artists, "", fn a -> ~s(<li class="py-2 px-1 text-gray-700">#{a}</li>) end)}
                </ul>
                <a href="/" class="text-indigo-600 hover:underline flex items-center gap-1">
                  ⬅ Back
                </a>
              </div>
              <footer class="text-sm mt-6 text-gray-400">Powered by Scryfall &amp; Moxfield</footer>
            </body>
          </html>
        """

        conn
        |> put_resp_content_type("text/html", "utf-8")
        |> send_resp(200, html)

      {:error, reason} ->
        html = """
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>Error</title>
              <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
            </head>
            <body class="bg-gray-100 flex flex-col items-center justify-center min-h-screen px-4">
              <div class="max-w-lg bg-white shadow-xl rounded-lg p-8 mt-20">
                <h3 class="text-lg font-bold text-red-600 mb-4">💥 Error: #{reason}</h3>
                <a href="/" class="text-indigo-600 hover:underline flex items-center gap-1">⬅ Back</a>
              </div>
            </body>
          </html>
        """

        conn
        |> put_resp_content_type("text/html", "utf-8")
        |> send_resp(400, html)
    end
  end

  match _ do
    send_resp(conn, 404, "404 Not found")
  end
end
