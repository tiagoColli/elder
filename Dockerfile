FROM elixir:1.18-otp-27-alpine

RUN apk add --no-cache build-base git inotify-tools

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

EXPOSE 4000

CMD ["mix", "phx.server"]
