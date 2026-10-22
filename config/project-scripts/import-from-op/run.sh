#!/usr/bin/env bash
# mu entry point: resolve a relative --dump against the mounted project folder.
# mu runs the script with cwd /script, so a relative path would not resolve.
# Paths are project-relative: only this project is mounted in the container at
# /app. A leading / is stripped (/data/dumps/x means data/dumps/x), a path with
# .. that leaves the project is refused, and an /app/... path is kept.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=${MU_APP_ROOT:-/app}

usage() {
  cat >&2 <<'EOF'
--dump takes the dump folder, which must hold op-rvs.nt and manifest.json.
In this project that folder is data/dumps/<stamp>:
  mu script project-scripts import-from-op --dump data/dumps/<stamp> [--dry-run]
EOF
  exit 2
}

resolve() {
  local path=$1
  case "$path" in
    --*)
      usage
      ;;
    /app/*)
      printf '%s\n' "$path"
      ;;
    *..*)
      printf 'error: --dump %s leaves this project; only this project is mounted in the script container.\n' "$path" >&2
      printf 'Copy the dump folder in first:\n  mkdir -p data/dumps && cp -r %s data/dumps/\n' "$path" >&2
      usage
      ;;
    /*)
      printf '%s\n' "$app${path}"
      ;;
    *)
      printf '%s\n' "$app/$path"
      ;;
  esac
}

args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dump)
      [ $# -ge 2 ] || usage
      args+=("--dump" "$(resolve "$2")")
      shift 2
      ;;
    *) args+=("$1"); shift ;;
  esac
done

exec bash "$here/import.sh" "${args[@]}"
