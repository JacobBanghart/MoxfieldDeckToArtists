<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# GetUniqueArtists

A simple Elixir web tool for extracting the list of unique artists from any Magic: The Gathering deck on Moxfield—designed both as a utility and as a platform for learning and experimenting with Elixir.

## How It Works

- **Web Interface:** Modern HTML UI (styled with Tailwind from a CDN) lets users paste any Moxfield deck URL and see a neatly formatted list of all unique artists credited in the deck.
- **API Workflow:**

1. **Input:** User provides a Moxfield deck URL.
2. **Moxfield API:** The app fetches deck details, extracting each card's Scryfall ID.
3. **Scryfall API:** Cards are looked up in Scryfall, batching requests for efficiency.
4. **Artist Aggregation:** Collects and deduplicates all artist names (including both regular and multi-face cards).
5. **Result Display:** Artists are sorted and shown in a responsive, styled HTML view.
- **Modern Elixir Stack:**
    - Built with Plug and Cowboy for the HTTP server.
    - Uses HTTPoison and Jason for HTTP requests and JSON handling.
    - Simple structure: minimal, no heavy frameworks.
- **Cloud-Ready:** Dockerized using an Alpine-based image for lightweight deployments; integrates easily with Kubernetes.
- **Continuous Delivery:** Builds and publishes images to GitHub Container Registry via GitHub Actions. Anyone can deploy or run locally.

## Running Locally

1. **Install Elixir 1.15+ and Docker (optional for container use)**
2. **Clone the repo:**

```sh
git clone https://github.com/JacobBanghart/MoxfieldDeckToArtists.git
cd get_unique_artists
```

3. **Install dependencies:**

```sh
mix deps.get
```

4. **Start the server:**

```sh
mix run --no-halt
```

Then visit: [http://localhost:4000](http://localhost:4000)

### Using Docker

```sh
docker run -p 4000:4000 ghcr.io/JacobBanghart/MoxfieldDeckToArtists:latest
```


## Roadmap \& Exploration

Enhance or extend by adding:

- Download as CSV
- Artist frequency charts or analytics
- Card art image previews
- Authentication, advanced search, or REST API endpoints

Use this project as a launchpad for exploring Elixir and BEAM in modern, cloud-native scenarios.

## License

MIT. All code is open for educational and remix purposes.

Built as a hands-on project to deepen Elixir skills and delight the Magic: The Gathering community. Contributions, feedback, and forks are encouraged.

