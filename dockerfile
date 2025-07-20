# --- Build Stage ---
FROM hexpm/elixir:1.15.4-erlang-26.0.2-alpine-3.18.0 AS build

ENV MIX_ENV=prod

# Install build tools
RUN apk add --no-cache build-base git

WORKDIR /app

# Cache install of dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod

# Copy app source
COPY lib lib

# Compile app
RUN mix compile

# --- Release Stage ---
FROM hexpm/elixir:1.15.4-erlang-26.0.2-alpine-3.18.0 AS app

WORKDIR /app

ENV MIX_ENV=prod

COPY --from=build /app/_build ./
COPY --from=build /app/deps ./deps
COPY --from=build /app/lib ./lib
COPY config config
COPY mix.exs mix.lock ./

EXPOSE 4000

CMD ["elixir", "--no-halt", "-S", "mix", "run"]

