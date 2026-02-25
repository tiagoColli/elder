FROM elixir:1.15-otp-26-alpine

RUN apk add --no-cache build-base git inotify-tools

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

EXPOSE 4000

CMD ["mix", "phx.server"]
