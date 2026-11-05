#!/bin/bash
set -e

uv run alembic upgrade head

uv run python -m bin.consumer &
consumer_pid=$!

uv run python -m bin.api &
api_pid=$!

shutdown() {
  kill "$api_pid" "$consumer_pid" 2>/dev/null || true
  wait "$api_pid" "$consumer_pid" 2>/dev/null || true
}
trap shutdown EXIT INT TERM

wait -n "$api_pid" "$consumer_pid"
