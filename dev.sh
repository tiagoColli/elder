#!/bin/bash

YELLOW="\033[1;33m"
BLUE="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

PROJECT="elder"
APP_CONTAINER="${PROJECT}_app"
DB_CONTAINER="${PROJECT}_db"

step_ok() { echo -e "${GREEN}✓ $1${NC}"; }
step_fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

cli_help() {
  echo -e "
${YELLOW}Elder Development CLI${NC}
${YELLOW}---------------------${NC}

Usage: ./dev.sh [command]

${YELLOW}Environment:${NC}
  ${BLUE}(no args)${NC}             start all containers
  ${BLUE}stop${NC}                  stop all containers
  ${BLUE}restart${NC}               restart all containers
  ${BLUE}rebuild${NC}               rebuild and restart all containers
  ${BLUE}clean${NC}                 stop containers and remove volumes
  ${BLUE}logs${NC}                  tail container logs
  ${BLUE}ps${NC}                    list running containers

${YELLOW}App:${NC}
  ${BLUE}shell${NC}                 open a shell inside the app container
  ${BLUE}iex${NC}                   attach to the running IEx session
  ${BLUE}run <cmd>${NC}             run a mix command inside the app container

${YELLOW}Database:${NC}
  ${BLUE}db${NC}                    connect to the dev database
  ${BLUE}db test${NC}               connect to the test database
  ${BLUE}db.setup${NC}              create and migrate the dev database
  ${BLUE}db.migrate${NC}            run pending migrations
  ${BLUE}db.reset${NC}              drop, create, and migrate the dev database

${YELLOW}Quality:${NC}
  ${BLUE}check${NC}                 run format + compile + credo + dialyzer + sobelow
  ${BLUE}test${NC}                  run all tests
  ${BLUE}test <path>${NC}           run tests for a specific file/path

${YELLOW}Other:${NC}
  ${BLUE}i${NC}                     interactive mode
  ${BLUE}h | help${NC}              show this help
"
}

cmd_start() {
  echo -e "${YELLOW}Starting elder dev environment...${NC}"
  docker compose up -d
  echo ""
  docker compose ps
  echo ""
  step_ok "Environment started"
}

cmd_stop() {
  echo -e "${YELLOW}Stopping containers...${NC}"
  docker compose down
  step_ok "Stopped"
}

cmd_restart() {
  echo -e "${YELLOW}Restarting containers...${NC}"
  docker compose restart
  step_ok "Restarted"
}

cmd_rebuild() {
  echo -e "${YELLOW}Rebuilding containers...${NC}"
  docker compose up -d --build
  step_ok "Rebuilt"
}

cmd_clean() {
  echo -e "${YELLOW}Stopping containers and removing volumes...${NC}"
  docker compose down -v
  step_ok "Cleaned"
}

cmd_logs() {
  docker compose logs -f --tail=100
}

cmd_ps() {
  docker compose ps
}

# `sh` not `/bin/sh`: Git Bash path-converts `/...` for docker.exe on Windows.
cmd_shell() {
  docker exec -it "$APP_CONTAINER" sh
}

cmd_iex() {
  docker attach "$APP_CONTAINER"
}

cmd_run() {
  docker exec -it "$APP_CONTAINER" mix "$@"
}

cmd_db() {
  local db_name="${PROJECT}_dev"
  if [ "$1" == "test" ]; then
    db_name="${PROJECT}_test"
  fi
  echo -e "${YELLOW}Connecting to ${db_name}...${NC}"
  PGPASSWORD="$PROJECT" psql -h localhost -U "$PROJECT" -p 5432 -d "$db_name"
}

cmd_db_setup() {
  echo -e "${YELLOW}Setting up database...${NC}"
  docker exec "$APP_CONTAINER" mix ecto.setup
  step_ok "Database set up"
}

cmd_db_migrate() {
  echo -e "${YELLOW}Running migrations...${NC}"
  docker exec "$APP_CONTAINER" mix ecto.migrate
  step_ok "Migrations complete"
}

cmd_db_reset() {
  echo -e "${YELLOW}Resetting database...${NC}"
  docker exec "$APP_CONTAINER" mix ecto.reset
  step_ok "Database reset"
}

cmd_check() {
  echo -e "${YELLOW}Running format...${NC}"
  docker exec "$APP_CONTAINER" mix format --check-formatted || step_fail "mix format failed"
  step_ok "format passed"
  echo ""

  echo -e "${YELLOW}Running compile --warnings-as-errors...${NC}"
  docker exec "$APP_CONTAINER" mix compile --warnings-as-errors || step_fail "compile failed"
  step_ok "compile passed"
  echo ""

  echo -e "${YELLOW}Running credo --strict...${NC}"
  docker exec "$APP_CONTAINER" mix credo --strict || step_fail "credo failed"
  step_ok "credo passed"
  echo ""

  echo -e "${YELLOW}Running dialyzer...${NC}"
  docker exec "$APP_CONTAINER" mix dialyzer || step_fail "dialyzer failed"
  step_ok "dialyzer passed"
  echo ""

  echo -e "${YELLOW}Running sobelow...${NC}"
  docker exec "$APP_CONTAINER" mix sobelow --config || step_fail "sobelow failed"
  step_ok "sobelow passed"
  echo ""

  step_ok "All checks passed!"
}

cmd_test() {
  if [ -z "$1" ]; then
    docker exec "$APP_CONTAINER" mix test
  else
    docker exec "$APP_CONTAINER" mix test "$@"
  fi
}

interactive() {
  echo -e "
${YELLOW}Select action:${NC}

  ${YELLOW}Environment${NC}
  1) start all containers
  2) stop all containers
  3) restart all containers
  4) rebuild all containers
  5) clean (stop + remove volumes)
  6) tail logs
  7) list running containers

  ${YELLOW}App${NC}
  8) open shell in app container
  9) attach to IEx session

  ${YELLOW}Database${NC}
  d) connect to dev database
  t) connect to test database
  s) setup database (create + migrate)
  m) run pending migrations
  r) reset database (drop + create + migrate)

  ${YELLOW}Quality${NC}
  c) run all checks (format+compile+credo+dialyzer+sobelow)
  x) run all tests

  ${YELLOW}Other${NC}
  h) help
  q) quit
"
  read -n 1 -p "→ " action
  echo ""
  echo ""

  case "$action" in
    1) cmd_start ;;
    2) cmd_stop ;;
    3) cmd_restart ;;
    4) cmd_rebuild ;;
    5) cmd_clean ;;
    6) cmd_logs ;;
    7) cmd_ps ;;
    8) cmd_shell ;;
    9) cmd_iex ;;
    d) cmd_db ;;
    t) cmd_db test ;;
    s) cmd_db_setup ;;
    m) cmd_db_migrate ;;
    r) cmd_db_reset ;;
    c) cmd_check ;;
    x) cmd_test ;;
    h) cli_help ;;
    q) exit 0 ;;
    *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
  esac
}

case "$1" in
  h|help)     cli_help ;;
  i)          interactive ;;
  stop)       cmd_stop ;;
  restart)    cmd_restart ;;
  rebuild)    cmd_rebuild ;;
  clean)      cmd_clean ;;
  logs)       cmd_logs ;;
  ps)         cmd_ps ;;
  shell)      cmd_shell ;;
  iex)        cmd_iex ;;
  run)        shift; cmd_run "$@" ;;
  db)         cmd_db "$2" ;;
  db.setup)   cmd_db_setup ;;
  db.migrate) cmd_db_migrate ;;
  db.reset)   cmd_db_reset ;;
  check)      cmd_check ;;
  test)       shift; cmd_test "$@" ;;
  *)          cmd_start ;;
esac
