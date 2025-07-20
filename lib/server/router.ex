defmodule GetUniqueArtists.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:urlencoded, :multipart])
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html", "utf-8")
    |> send_resp(200, """
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset=\"UTF-8\">
          <title>🎨 MTG Artists Finder</title>
          <script src=\"https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4\"></script>
        </head>
        <body class=\"bg-gray-100 min-h-screen flex flex-col justify-center items-center px-4\">
          <div class=\"w-full max-w-lg mt-24 bg-white shadow-xl rounded-lg p-8\">
            <h1 class=\"text-3xl font-bold text-indigo-700 mb-3 flex items-center gap-2\">🎨 MTG Unique Artists</h1>
            <p class=\"mb-6 text-gray-500\">Paste your Moxfield deck URL below to view a list of all unique artists in your deck.</p>
            <form method=\"GET\" action=\"/artists\" class=\"flex flex-col space-y-4\" aria-label=\"Moxfield deck URL form\" onsubmit=\"return validateUrl();\">
              <input
                type=\"text\"
                name=\"url\"
                placeholder=\"https://moxfield.com/decks/your-deck-id\"
                class=\"rounded-lg border-2 border-gray-300 px-4 py-3 text-base focus:outline-none focus:border-indigo-600 focus:ring-2 focus:ring-indigo-400 placeholder-gray-400 transition\"
                required
                pattern=\"https://(www\\.)?moxfield\\.com/decks/[a-zA-Z0-9_-]+\"
                aria-label=\"Moxfield deck URL\"
              />
              <span id=\"url-error\" class=\"text-red-600 text-sm hidden\"></span>
              <button type=\"submit\" class=\"bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded-lg transition focus:outline-none focus:ring-2 focus:ring-indigo-400\" aria-label=\"Fetch Artists\">
                ➡️ Fetch Artists
              </button>
            </form>
          </div>
          <footer class=\"text-sm mt-6 text-gray-400\">Powered by Scryfall &amp; Moxfield</footer>
          <script>
            function validateUrl() {
              var input = document.querySelector('input[name=url]');
              var error = document.getElementById('url-error');
              var pattern = new RegExp('^https://(www\\.)?moxfield\\.com/decks/[a-zA-Z0-9_-]+$');
              if (!pattern.test(input.value)) {
                error.textContent = 'Please enter a valid Moxfield deck URL.';
                error.classList.remove('hidden');
                input.classList.add('border-red-500');
                input.focus();
                return false;
              } else {
                error.classList.add('hidden');
                input.classList.remove('border-red-500');
                return true;
              }
            }
          </script>
        </body>
      </html>
    """)
  end

  get "/artists" do
    deck_url = conn.params["url"]

    # Validate Moxfield deck URL format
    moxfield_regex = ~r/^https:\/\/(www\.)?moxfield\.com\/decks\/[a-zA-Z0-9_-]+$/
    if deck_url == nil or not Regex.match?(moxfield_regex, deck_url) do
      html = """
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset=\"UTF-8\">
            <title>Error</title>
            <script src=\"https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4\"></script>
          </head>
          <body class=\"bg-gray-100 flex flex-col items-center justify-center min-h-screen px-4\">
            <div class=\"max-w-lg bg-white shadow-xl rounded-lg p-8 mt-20\">
              <h3 class=\"text-lg font-bold text-red-600 mb-4\">💥 Error: Invalid Moxfield deck URL.</h3>
              <a href=\"/\" class=\"text-indigo-600 hover:underline flex items-center gap-1\">⬅ Back</a>
            </div>
          </body>
        </html>
      """

      conn
      |> put_resp_content_type("text/html", "utf-8")
      |> send_resp(400, html)
    else
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
          # Log the error for debugging
          require Logger
          Logger.error("Failed to fetch artists for URL #{deck_url}: #{inspect(reason)}")

          user_message =
            case reason do
              :invalid_url -> "The provided URL is not a valid Moxfield deck."
              :network_error -> "There was a problem connecting to Moxfield or Scryfall. Please try again later."
              :api_error -> "An error occurred while fetching data from the API."
              _ -> "An unexpected error occurred. Please check your URL and try again."
            end

          html = """
            <!DOCTYPE html>
            <html>
              <head>
                <meta charset=\"UTF-8\">
                <title>Error</title>
                <script src=\"https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4\"></script>
              </head>
              <body class=\"bg-gray-100 flex flex-col items-center justify-center min-h-screen px-4\">
                <div class=\"max-w-lg bg-white shadow-xl rounded-lg p-8 mt-20\">
                  <h3 class=\"text-lg font-bold text-red-600 mb-4\">💥 Error: #{user_message}</h3>
                  <a href=\"/\" class=\"text-indigo-600 hover:underline flex items-center gap-1\">⬅ Back</a>
                </div>
              </body>
            </html>
          """

          conn
          |> put_resp_content_type("text/html", "utf-8")
          |> send_resp(400, html)
      end
    end
  end

  match _ do
    html = """
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset=\"UTF-8\">
          <title>404 Not Found</title>
          <script src=\"https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4\"></script>
        </head>
        <body class=\"bg-gray-100 flex flex-col items-center justify-center min-h-screen px-4\">
          <div class=\"max-w-lg bg-white shadow-xl rounded-lg p-8 mt-20 text-center\">
            <h1 class=\"text-3xl font-bold text-red-600 mb-4\">404 - Page Not Found</h1>
            <p class=\"mb-6 text-gray-500\">Sorry, the page you are looking for does not exist.</p>
            <a href=\"/\" class=\"text-indigo-600 hover:underline flex items-center gap-1\">⬅ Back to Home</a>
          </div>
          <footer class=\"text-sm mt-6 text-gray-400\">Powered by Scryfall &amp; Moxfield</footer>
        </body>
      </html>
    """
    send_resp(conn, 404, html)
  end
end
