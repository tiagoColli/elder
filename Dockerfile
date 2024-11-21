# Use an official Elixir image as the base
FROM elixir:1.17-alpine

# Install build tools and dependencies
RUN apk add --no-cache build-base git nodejs npm

# Set the working directory inside the container
WORKDIR /app

# Copy the mix files and fetch dependencies
COPY mix.exs mix.lock ./
RUN mix do local.hex --force, local.rebar --force, deps.get

# Copy the rest of the application code
COPY . .

# Compile the project
RUN mix deps.compile

# Expose the port the app will run on
EXPOSE 4000

# Command to start the Phoenix server
CMD ["mix", "phx.server"]

