#!/bin/bash
set -uo pipefail

# Прямой запуск из venv, собранного в образе, — быстрее, чем `uv run`
# (не тратит время на повторную компиляцию байткода при каждом старте).
if [ -x /app/.venv/bin/python ]; then
  PYTHON=(/app/.venv/bin/python)
else
  PYTHON=(uv run python)
fi

pids=()

stop() {
  trap - EXIT INT TERM
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  exit 0
}
trap stop EXIT INT TERM

# 1. Сначала поднимаем API, чтобы порт начал слушаться как можно раньше.
"${PYTHON[@]}" -m bin.api &
pids+=($!)

# 2. Миграции. API не обращается к БД на старте, поэтому можно применять
#    их параллельно; запросы, пришедшие в первые секунды, уже не получат 502.
attempt=1
until "${PYTHON[@]}" -m alembic upgrade head; do
  echo "[run.sh] migrations failed (attempt $attempt), retrying in 2s" >&2
  attempt=$((attempt + 1))
  sleep 2
done
echo "[run.sh] migrations applied" >&2

# 3. Consumer в отдельном супервизоре: его падение не роняет API.
(
  trap 'exit 0' TERM INT
  while true; do
    "${PYTHON[@]}" -m bin.consumer
    echo "[run.sh] consumer exited, restarting in 2s" >&2
    sleep 2
  done
) &
pids+=($!)

wait "${pids[0]}"
