# --- Build Stage ---
FROM elixir:1.18.4-alpine AS build

ENV MIX_ENV=prod

RUN apk add --no-cache build-base git

WORKDIR /app

# Install Hex and Rebar for build
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY lib lib

RUN mix compile

# --- Release Stage ---
FROM elixir:1.18.4-alpine AS app

WORKDIR /app

ENV MIX_ENV=prod

# Install Hex and Rebar for Mix runtime tasks (if any)
RUN mix local.hex --force && mix local.rebar --force

COPY --from=build /app/_build ./_build
COPY --from=build /app/deps ./deps
COPY --from=build /app/lib ./lib
COPY mix.exs mix.lock ./

EXPOSE 4000

CMD ["elixir", "--no-halt", "-S", "mix", "run"]

