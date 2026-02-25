FROM elixir:1.15-otp-26-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

COPY mix.exs mix.lock* ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix deps.compile

COPY . .

CMD ["iex", "-S", "mix"]
