# Define the mix commands for convenience
MIX = docker-compose run --rm elder mix
DB_CONTAINER = postgres_db

# Run dev environment
.PHONY: run
run: deps db.create start

# Run all tests
.PHONY: test
test:
	MIX_ENV=test $(MIX) test

# Update project dependencies
.PHONY: deps
deps:
	$(MIX) deps.get
	$(MIX) deps.compile

# Create the database
.PHONY: db.create
db.create:
	$(MIX) ecto.create
	$(MIX) ecto.migrate

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

# Run Dialyzer for static analysis
.PHONY: dialyzer
dialyzer:
	$(MIX) dialyzer

# Run Credo for code style checks
.PHONY: credo
credo:
	$(MIX) credo --strict

# Run Sobelow for security analysis
.PHONY: sobelow
sobelow:
	$(MIX) sobelow

# Run ExCoveralls to generate a coverage report
.PHONY: coveralls
coveralls:
    # Set MIX_ENV to test to generate a coverage report for the test environment
    MIX_ENV=test $(MIX) coveralls.html

# Run CI pipeline locally
.PHONY: ci
ci: deps dialyzer credo sobelow coveralls
