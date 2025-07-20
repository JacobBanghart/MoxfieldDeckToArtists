defmodule GetUniqueArtists.Application do
  use Application

  require Logger

  def start(_type, _args) do
    Logger.info("Starting GetUniqueArtists web server...")
    Logger.info("🌐 Visit http://localhost:4000 to use the tool")

    children = [
      {Plug.Cowboy,
       scheme: :http, plug: GetUniqueArtists.Router, options: [port: 4000, ip: {0, 0, 0, 0}]},
      Cache.InMemory
    ]

    opts = [strategy: :one_for_one, name: GetUniqueArtists.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
