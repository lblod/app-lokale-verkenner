#!/usr/bin/env bash
# Import an export directory (export.sh's output) into RVS.
#
# Insert-only: the dump is added to the target graph and nothing is deleted.
# Re-running the same dump changes nothing (triples are a set); a newer dump
# adds new data but does not remove what OP has deleted.
#
# One-shot per environment, run before the rest of the stack's migrations. The
# migrations that seed the same data are disabled by hand — see README.md,
# "Conflicting migrations".
#
# Modes:
#   (default)   insert the dump into RVS_GRAPH, then verify the graph against
#               the dump's manifest.
#   --dry-run   read RVS_GRAPH as a pre-flight, then insert into RVS_STAGING and
#               verify there. RVS_GRAPH is not written; staging is cleared
#               afterwards.
#
# Usage: import.sh --dump DIR [--dry-run] [--graph IRI] [--staging IRI]
# Environment: RVS_SPARQL_ENDPOINT, RVS_SPARQL_USER, RVS_SPARQL_PASSWORD.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

# RVS reads administrative-unit. This is the graph the dump goes into.
RVS_GRAPH=${RVS_GRAPH:-http://mu.semte.ch/graphs/administrative-unit}
RVS_STAGING=${RVS_STAGING:-http://mu.semte.ch/graphs/rvs-dump-staging}
RVS_SPARQL_ENDPOINT=${RVS_SPARQL_ENDPOINT:-http://triplestore:8890/sparql/}
RVS_SPARQL_USER=${RVS_SPARQL_USER:-dba}
RVS_SPARQL_PASSWORD=${RVS_SPARQL_PASSWORD:-dba}

dump=
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dump) dump=$2; shift 2; continue ;;
    --graph) RVS_GRAPH=$2; shift 2; continue ;;
    --staging) RVS_STAGING=$2; shift 2; continue ;;
    --dry-run) dry_run=1 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

log() { printf '[import %s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "error: $*"; exit 1; }

[ -n "$dump" ] || die "--dump is required, and must be the dump folder (data/dumps/<stamp>)"
if [ ! -d "$dump" ]; then
  if [ -e "$dump" ]; then
    die "$dump is a file, not a dump folder. --dump takes the folder that holds op-rvs.nt and manifest.json, e.g. data/dumps/<stamp>"
  fi
  die "$dump does not exist inside the script container, which sees only this project at /app. Copy the dump into the project (mkdir -p data/dumps && cp -r <source> data/dumps/) and pass --dump data/dumps/<stamp>"
fi
[ -f "$dump/op-rvs.nt" ] || die "$dump/op-rvs.nt not found: $dump is not an export folder (it must hold op-rvs.nt and manifest.json)"
[ -f "$dump/manifest.json" ] || die "$dump/manifest.json not found: $dump is not an export folder (it must hold op-rvs.nt and manifest.json)"

# --- plumbing -----------------------------------------------------------------
# Everything goes through a file: the dump chunks are over the kernel's argv
# limit, and a placeholder in a long comment changes how the store reads the
# query (see queries/export-page.rq).

substitute() {
  # substitute FILE OUT [key value]...: prefixes on top, placeholders filled in
  # the query text only.
  local file=$1 out=$2
  shift 2
  local text
  text=$(cat "$file")
  while [ $# -gt 1 ]; do
    text=${text//"$1"/"$2"}
    shift 2
  done
  cat "$here/queries/prefixes.rq" > "$out"
  printf '%s\n' "$text" >> "$out"
}

select_value() {
  # select_value QUERY_FILE [key value]...: the one cell of a one-row SELECT.
  local file=$1 query
  shift
  query=$(mktemp)
  substitute "$file" "$query" "$@"
  curl --fail --silent --show-error --user "$RVS_SPARQL_USER:$RVS_SPARQL_PASSWORD" \
    -G --data-urlencode "query@$query" -H 'Accept: text/csv' "$RVS_SPARQL_ENDPOINT" \
    | sed -n '2p' | tr -d '\r"'
  rm -f "$query"
}

update_file() {
  curl --fail --silent --show-error --user "$RVS_SPARQL_USER:$RVS_SPARQL_PASSWORD" \
    -H 'Content-Type: application/sparql-update' \
    --data-binary "@$1" "$RVS_SPARQL_ENDPOINT" >/dev/null
}

clear_graph() {
  local body
  body=$(mktemp)
  printf 'CLEAR GRAPH <%s>\n' "$1" > "$body"
  update_file "$body"
  rm -f "$body"
}

insert_file() {
  # insert_file GRAPH NT_FILE: INSERT DATA per 500 triples. Virtuoso refuses a
  # single INSERT DATA whose generated SQL exceeds 10,000 lines (~1,500
  # triples). This is the only write the import does: no delete, no replace.
  local graph=$1 file=$2 chunks body chunk
  [ -s "$file" ] || return 0
  cp "$file" "$file.partial"
  chunks=$(mktemp -d)
  split -l 500 "$file.partial" "$chunks/chunk."
  body=$(mktemp)
  for chunk in "$chunks"/chunk.*; do
    {
      printf 'INSERT DATA { GRAPH <%s> {\n' "$graph"
      cat "$chunk"
      printf '} }\n'
    } > "$body"
    update_file "$body"
  done
  rm -rf "$chunks" "$body" "$file.partial"
}

target=$RVS_GRAPH
[ "$dry_run" -eq 1 ] && target=$RVS_STAGING

log "endpoint $RVS_SPARQL_ENDPOINT, target graph $target"
log "dump $dump"

# Pre-flight the real graph in both modes, before anything is written. This
# catches a wrong endpoint, credentials, graph IRI or Virtuoso-level permission
# before the point of no return. It does not prove the app reads the graph: the
# script talks to Virtuoso directly, so the sparql-parser read rule in
# config/authorization/ is not on this path. A failure here is most often that
# missing rule, though.
real=$(select_value "$here/queries/graph-count.rq" '@GRAPH@' "<$RVS_GRAPH>") \
  || die "cannot read $RVS_GRAPH at $RVS_SPARQL_ENDPOINT. Check RVS_SPARQL_ENDPOINT and the credentials; if those are right, the likely cause is a missing read rule for graphs/administrative-unit in RVS's config/authorization/"
[[ $real =~ ^[0-9]+$ ]] \
  || die "cannot read $RVS_GRAPH at $RVS_SPARQL_ENDPOINT (got '$real'). Check RVS_SPARQL_ENDPOINT and the credentials; if those are right, the likely cause is a missing read rule for graphs/administrative-unit in RVS's config/authorization/"
log "$RVS_GRAPH holds $real triples"

# RVS keeps its mock-login accounts in graphs/public, keyed on the
# organisations. The import never deletes, so their count must not change;
# counting them catches a wrong target graph or a stray write.
RVS_ACCOUNTS_GRAPH=${RVS_ACCOUNTS_GRAPH:-http://mu.semte.ch/graphs/public}
accounts_before=$(select_value "$here/queries/type-count.rq" \
  '@GRAPH@' "<$RVS_ACCOUNTS_GRAPH>" \
  '@TYPE@' "<http://xmlns.com/foaf/0.1/OnlineAccount>")

before=$(select_value "$here/queries/graph-count.rq" '@GRAPH@' "<$target>")
log "$target holds $before triples"

if [ "$dry_run" -eq 1 ]; then
  clear_graph "$RVS_STAGING"
  log "cleared $RVS_STAGING for the dry run"
fi

log "inserting the dump into $target"
insert_file "$target" "$dump/op-rvs.nt"

after=$(select_value "$here/queries/graph-count.rq" '@GRAPH@' "<$target>")
log "$target now holds $after triples"

log "verifying $target"
if [ "$dry_run" -eq 1 ]; then
  # The staging graph is the reference for the dry run, so it compares against
  # itself; the verification notes that and skips the subject-set checks.
  # The account graph is read-only in a dry run, so its count must be
  # unchanged: a mismatch means the graph or the credentials are not what the
  # operator thinks, before anything is inserted.
  python3 "$here/verify-import.py" \
    --dump "$dump" \
    --endpoint "$RVS_SPARQL_ENDPOINT" \
    --user "$RVS_SPARQL_USER" --password "$RVS_SPARQL_PASSWORD" \
    --graph "$RVS_STAGING" \
    --staging "$RVS_STAGING" \
    --account-graph "$RVS_ACCOUNTS_GRAPH" \
    --account-count "$accounts_before"
  clear_graph "$RVS_STAGING"
  log "done: staging cleared, $RVS_GRAPH untouched"
  exit 0
fi

# A real import compares the graph against the dump it came from. The dump is
# staged only as the reference for that check, then cleared: it is import
# bookkeeping and does not belong in RVS.
clear_graph "$RVS_STAGING"
log "staged into $RVS_STAGING (reference for the verification)"
insert_file "$RVS_STAGING" "$dump/op-rvs.nt"

python3 "$here/verify-import.py" \
  --dump "$dump" \
  --endpoint "$RVS_SPARQL_ENDPOINT" \
  --user "$RVS_SPARQL_USER" --password "$RVS_SPARQL_PASSWORD" \
  --graph "$RVS_GRAPH" \
  --staging "$RVS_STAGING" \
  --account-graph "$RVS_ACCOUNTS_GRAPH" \
  --account-count "$accounts_before"

clear_graph "$RVS_STAGING"
log "done: dump inserted into $RVS_GRAPH, staging cleared"
