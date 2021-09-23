#!/usr/bin/bash

set -eux
set -o pipefail

SERVERPORT=8080
SERVERADDR=localhost:${SERVERPORT}
GQLPATH=http://${SERVERADDR}/query

# Submit some seed data to the server initially
curl ${GQLPATH} \
    -w "\n" -H 'Content-Type: application/json' \
    --data-binary '{"query":"mutation {\n  createTodo(input: { text: \"sample todo 1\", userId: \"2\" }) { id text done }\n}"}'

curl ${GQLPATH} \
    -w "\n" -H 'Content-Type: application/json' \
    --data-binary '{"query":"mutation {\n  createTodo(input: { text: \"sample todo 2\", userId: \"2\" }) { id text done }\n}"}'

curl ${GQLPATH} \
    -w "\n" -H 'Content-Type: application/json' \
    --data-binary '{"query":"mutation {\n  createTodo(input: { text: \"sample todo 3\", userId: \"3\" }) { id text done }\n}"}'
