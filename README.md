# Elder

[![Coverage Status](https://coveralls.io/repos/github/tiagoColli/elder/badge.svg)](https://coveralls.io/github/tiagoColli/elder)

An Elixir web application built with Phoenix LiveView.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

## Getting Started

```bash
# Start containers (Postgres + app)
./dev.sh

# First-time setup: install deps, create DB, install assets
./dev.sh run setup

# Create and migrate the database (if setup was already run)
./dev.sh run ecto.setup
```

The app will be available at [http://localhost:4000](http://localhost:4000).

## Development

All commands run inside Docker via `./dev.sh`:

| Command | Description |
|---|---|
| `./dev.sh` | Start all containers |
| `./dev.sh stop` | Stop all containers |
| `./dev.sh restart` | Restart all containers |
| `./dev.sh rebuild` | Rebuild and restart |
| `./dev.sh clean` | Stop and remove volumes |
| `./dev.sh logs` | Tail container logs |
| `./dev.sh ps` | List running containers |
| `./dev.sh shell` | Shell into app container |
| `./dev.sh iex` | Attach to IEx session |
| `./dev.sh run <cmd>` | Run a mix command |
| `./dev.sh db` | Connect to dev database |
| `./dev.sh db test` | Connect to test database |
| `./dev.sh db.setup` | Create + migrate dev DB |
| `./dev.sh db.migrate` | Run pending migrations |
| `./dev.sh db.reset` | Drop + recreate dev DB |
| `./dev.sh check` | Run format + compile + credo + dialyzer |
| `./dev.sh test` | Run all tests |
| `./dev.sh test <path>` | Run specific tests |
| `./dev.sh i` | Interactive mode |

## Stack

- **Elixir** 1.15 / **OTP** 26
- **Phoenix** 1.7 + **LiveView**
- **PostgreSQL** 16
- **Ecto** for database
- **Tailwind CSS** for styling
- **Bandit** HTTP server
