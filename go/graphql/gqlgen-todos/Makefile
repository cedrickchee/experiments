default: generate

# Runs the gqlgen GraphQL codegen tool whenever a schema or model changes.
generate:
	go generate ./...

run/server:
	@go run cmd/todo/*

.PHONY: default generate run/server