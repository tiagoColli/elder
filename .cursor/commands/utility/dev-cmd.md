---
description: "Add/update a command in dev.sh (consistent style; minimal diff; always plan+patch)"
---

IN:
  CMD=<command name>;
  DESCRIPTION=<what it does>;
  ARGS=<optional args the command accepts>;
  CTX=<optional notes|paste>;
  MODE=plan+patch|patch(def plan+patch);

RULES:
  - dev.sh-only change: modify ONLY dev.sh. No other files.
  - Read dev.sh first. Understand the existing structure, naming, and patterns before any change.
  - Follow the existing conventions exactly:
    - Each command is a function named cmd_<name>().
    - Functions use $APP_CONTAINER, $DB_CONTAINER, $PROJECT variables — never hardcode container names.
    - Use step_ok/step_fail helpers for user feedback.
    - Use the color variables (YELLOW, BLUE, GREEN, RED, NC) for output — never raw escape codes.
    - Commands that accept sub-arguments use shift + "$@" pattern.
    - Keep functions small (< 20 lines). If complex, extract helper functions prefixed with _<name>.
  - Register the command in THREE places:
    1) cli_help() — add an entry under the correct section (Environment / App / Database / Quality / Other) matching the existing format and alignment.
    2) interactive() — add a menu entry in the corresponding section, using the next available number/letter key. Keep the grouping consistent with cli_help sections.
    3) case "$1" block at the bottom — add a case entry in the same position order as cli_help.
  - If updating an existing command, preserve its case entry position and help entry position.
  - No inline comments unless they clarify a non-obvious constraint.
  - Small diff discipline: add only what is needed. Do not reformat or reorder existing code.

DOCKER EXEC RULES:
  - Interactive commands (shell, psql, iex): use docker exec -it.
  - Non-interactive commands (mix tasks, checks): use docker exec (no -it) unless the command needs TTY.
  - Always use "$APP_CONTAINER" or "$DB_CONTAINER" — never bare container names.

SAFETY:
  - Destructive commands (docker down -v, rm -rf, drop database) must prompt the user for confirmation before executing.
  - Pattern:
    ```
    read -p "Are you sure? This will <describe effect>. [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
    ```

OUTPUT:
  MODE=plan+patch => PLAN (3-8 bullets, max 600 chars) then unified diff; MODE=patch => diff only. No commentary outside contract.

PLAN FORMAT (tight):
  - Goal:
  - Command name + args:
  - Help section:
  - Function(s) added/changed:
  - Risk (breaking existing commands):

POST (ask mode):
  - Prompt user to verify:
    - ./dev.sh help (check help entry renders correctly)
    - ./dev.sh <cmd> (smoke test the new command)

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /dev-cmd CMD="deps" DESCRIPTION="Get and compile all dependencies" ARGS=""
  /dev-cmd CMD="format" DESCRIPTION="Run mix format on the project" ARGS="optional file path"
  /dev-cmd CMD="seed" DESCRIPTION="Run database seeds" ARGS="optional seed file" CTX="Seeds live in priv/repo/seeds.exs"
