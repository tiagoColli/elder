# Define the mix commands for convenience
MIX = docker-compose run --rm elder mix
DB_CONTAINER = postgres_db

# Default target
.PHONY: all
all: deps db.create start

# Update project dependencies
.PHONY: deps
deps:
	$(MIX) deps.get
	$(MIX) deps.compile

# Create the database
.PHONY: db.create
db.create:
	$(MIX) ecto.create

# Reset the database (drop and create)
.PHONY: db.reset
db.reset:
	$(MIX) ecto.drop
	$(MIX) ecto.create
	$(MIX) ecto.migrate

# Start the project
.PHONY: start
start:
	docker-compose up elder

# Clean up the project containers
.PHONY: clean
clean:
	docker-compose down --volumes
