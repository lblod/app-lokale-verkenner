# Import an OP dump into RVS

Inserts a dump written by OP's `export-to-rvs` script into RVS and verifies it. This is the
import half of the OP → RVS sync; the export lives in
`Projects/OP/app-organization-portal/scripts/project/export-to-rvs/`.

## Running it

Both the script and the triplestore must be running — `mu` only *creates* the script
container:

```sh
docker compose up -d triplestore project-scripts
mu script project-scripts import-from-op --dump data/dumps/<stamp>
mu script project-scripts import-from-op --dump data/dumps/<stamp> --dry-run
```

`--dump` is a **folder**, not the `.nt` file, containing `op-rvs.nt` and `manifest.json`.
It must live inside this project: write it as `data/dumps/<stamp>`. The script container
sees only this project, at `/app`, so a path out of it cannot resolve:
`/data/dumps/<stamp>` is read as `data/dumps/<stamp>` (a leading `/` is dropped), and
`../../OP/app-organization-portal/data/dumps/<stamp>` is refused. Copy the folder in first:

```sh
cp -r ../OP/app-organization-portal/data/dumps/<stamp> data/dumps/
```

`data/dumps/` is git-ignored and may not exist yet: `mkdir -p data/dumps` before the copy.

From a laptop against RVS dev, call `import.sh` directly, not the `run.sh` wrapper:

```sh
RVS_SPARQL_ENDPOINT=http://localhost:8899/sparql/ \
  bash config/project-scripts/import-from-op/import.sh --dump /path/to/dump --dry-run
```

`run.sh` exists only for `mu`: it rewrites `data/dumps/<stamp>` to `/app/data/dumps/<stamp>`,
a path that exists inside the script container and nowhere else. Run from a laptop it
therefore fails with "does not exist inside the script container" even when the folder is
right. `import.sh` takes the path as given; point it at your store with the environment
variables below (`RVS_SPARQL_ENDPOINT` and the credentials), since its defaults name the
container's `triplestore`.

Both scripts are bash: `bash <script>`, not `sh <script>` (`sh` is dash on Debian and
cannot parse `args+=()`).

| Variable | Default |
| --- | --- |
| `RVS_SPARQL_ENDPOINT` | `http://triplestore:8890/sparql/` |
| `RVS_SPARQL_USER` / `RVS_SPARQL_PASSWORD` | `dba` / `dba` |
| `RVS_GRAPH` | `http://mu.semte.ch/graphs/administrative-unit` |
| `RVS_STAGING` | `http://mu.semte.ch/graphs/rvs-dump-staging` |
| `RVS_ACCOUNTS_GRAPH` | `http://mu.semte.ch/graphs/public` |

`--dump` is a relative path against the project folder (the wrapper rewrites it to
`/app/<path>`); an absolute path is passed through. `--dry-run` rehearses without writing
the target graph.

The script holds the RVS credentials (`dba` by default) because it writes directly to
Virtuoso: ~1.4M triples in 500-triple chunks, and the staging graph. That is the trade-off
for speed.

## Additive, one-shot

The import **only inserts. It never deletes.** Triples are a set, so re-running the same
dump changes nothing. A newer dump adds new data but does not remove what OP has deleted.
If you need OP's deletions, wipe by hand.

Import once per environment, before the rest of the stack's migrations. When testing an
import, start from a pristine copy of `data/db/virtuoso.db` so the result is clean.

## Procedure

1. **Confirm the target environment.** The import is additive and one-shot; the wrong
   target is not reversible. Check `RVS_SPARQL_ENDPOINT` and `RVS_GRAPH`.
2. **Dry run** on the target: `mu script project-scripts import-from-op --dump data/dumps/<stamp> --dry-run`.
3. **Disable the conflicting migrations** (next section).
4. **Import**: `mu script project-scripts import-from-op --dump data/dumps/<stamp>`. Inserts
   ~1.4M triples, then verifies.
5. **Start the stack and confirm RVS reads `graphs/administrative-unit`.** A successful
   import into a graph the app cannot read ends in an empty UI; the script
   cannot prove the read rule (see below).
6. Record the manifest's `stamp` and counts in the environment's notes.

## What a dry run covers

A dry run:

- reads `RVS_GRAPH` as a pre-flight, so it fails on a wrong endpoint, credentials, graph
  IRI or Virtuoso-level permission before staging anything. The failure message names the
  read rule in `config/authorization/` as the likely cause when the store refuses;
- writes the dump into `RVS_STAGING` and verifies the bytes there against the manifest;
- checks the `foaf:OnlineAccount` count in `graphs/public` is unchanged — that graph is
  not written by a dry run, so a mismatch means the graph or credentials are not what the
  operator thinks.

A dry run does **not** write to `administrative-unit` and does **not** run the
subject-set check (staging is compared with itself). The script talks to Virtuoso
directly, so the sparql-parser read rule in `config/authorization/` is not on its path: a
missing read rule passes the script and only shows up in the UI. Step 5 is the gate for
that.

## Conflicting migrations

RVS's migrations seed organisations, governing bodies, codelists and mock-login accounts.
An environment that imports a dump must not also run the seeds for organisations, bodies
and codelists — they add a second copy of data the dump already brings.

The shared folder `config/migrations/` holds what every environment runs. The conflicting
seeds live in `config/dev-migrations/`, which `docker-compose.dev.yml` mounts at
`/data/migrations/dev/` next to the shared set, as app-organization-portal does with its
`config/dev-migrations/`: a local stack without a dump gets the seeds, DEV, QA and PRD
never see them. A local stack that imports a dump comments that mount out in
`docker-compose.dev.yml` before its first start. The folder is committed, not git-ignored:
the moved files are copies of committed migrations, and keeping them in git makes the list
reviewable.

| Migration | Why it moves |
| --- | --- |
| `20261013120000-add-bestuurseenheden` (.ttl + .graph) | Seeds the units the dump already brings, with the same IRIs. |
| `20261013120004-add-bestuurseenheidClassificatieCodes` (.ttl + .graph) | Seeds the classification codes 2,912 dump triples reference. |

Kept in `config/migrations/`, each checked against the dump:

| Migration | Why it stays |
| --- | --- |
| `...120001-add-org-type-to-bestuurseenheden` | A no-op after import (the dump's RVS-25 typing is complete); needed on seed environments. |
| `...120002-add-economische-actor-classification` | The dump has no `ACMIDMOrganisationClassification`; the mock-EA login depends on it. |
| `...120003-add-mock-economische-actor` | The mock organisation is RVS-only; the dump does not carry it. |
| `...120005-add-bestuurseenheden-accounts` | Accounts are RVS's own, not the dump's. Note: it keys on units in `graphs/public`, so on a fresh dump environment it inserts nothing; only the mock-EA account exists there. |

Decide per migration by reading it, not by filename. A migration that seeds
organisations, bodies or codelists conflicts; one that only adds mock-login accounts does
not — nothing deletes them, and the verification counts them.

The migrations service records what it ran; switching the mounted folder is not a
rollback. On a database that already has the seeds applied, the moved migrations are
simply not seen again.

## Verification

`verify-import.py` compares the graph against the dump's manifest and fails the run on any
mismatch:

- per class, triple count and subject count match the manifest. A manifest whose counts
  are all zero is refused before the comparison: it would pass on any graph, dump or not;
- every subject from the dump is in the graph with at least as many triples as in the dump.
  A subject missing altogether fails, and so does one that lost a triple (a uuid, a label)
  even though it keeps its type. Extra triples are fine — the graph may hold RVS's own
  data;
- no worship type or subject;
- every unit and governing body has the `org:Organization` type;
- every governing body `bestuurt` a unit or registered organisation, or is a time
  specialisation of one that does;
- the `foaf:OnlineAccount` count in `graphs/public` is unchanged.

Staging is cleared after both a dry run and a real one.

## Moving the dump

The two stacks are separate compose projects with separate default networks, so a script
in OP cannot reach RVS's `triplestore` by alias. The dump has to move between the hosts
by hand, into RVS's project folder at the path the import reads:

```sh
tar -C data/dumps -czf - 261022101500 | ssh rvs-host 'tar -C <rvs>/data/dumps -xzf -'
```

Three things are also manual, not part of the command: the dump must land in RVS's project
folder; the conflicting migrations must be out of the way (above); and RVS must be able to
read `graphs/administrative-unit` (a rule in `config/authorization/`, outside the script).

To remove the file move later: a shared external Docker network
(`networks: { shared: { external: true } }` in both stacks, then point
`OP_SPARQL_ENDPOINT` / `RVS_SPARQL_ENDPOINT` at each other's service names), or streaming
the dump over `curl` from one host to the other. Both change the deployment topology and
are out of scope here.

## Ports

| Stack | In-network alias | Laptop |
| --- | --- | --- |
| OP | `http://triplestore:8890/sparql/` | `http://localhost:8890/sparql/` |
| RVS | `http://triplestore:8890/sparql/` | `http://localhost:8899/sparql/` |

The host ports are in each stack's `docker-compose.dev.yml`. Inside a mu script the
in-network alias works because the script joins the stack network.

## Virtuoso quirks (7.20.3241)

Workarounds are baked into the queries; listed here so they are not rediscovered.

- `FILTER NOT EXISTS` returns wrong answers — use `MINUS`.
- `COUNT(DISTINCT ?s, ?p, ?o)` does not work; count `SELECT DISTINCT ?s ?p ?o` in a sub-select.
- A `COUNT` over a `UNION` of graphs counts a triple once per graph it sits in.
- `VALUES` joined with `COUNT(DISTINCT)` gives wrong counts; count one class per query.
- Sorted `TOP` fails past ~10,000 rows with OFFSET — page by subject cursor. Never cut a page on triples: a subject straddling the cut loses its remainder.
- `INSERT DATA` fails past ~1,500 triples (`SP031`) — write in 500-triple chunks.
- `COPY` and single `INSERT` of ~5M triples both fail (150 MB transaction limit; hash dictionary limit) — do not materialise large filtered graphs; filter while paging out.
- `?s > <iri>` never matches — compare `STR(?s)`.
- `CONSTRUCT … WHERE { ?s ?p ?o }` over `FROM` drops literals — wrap in a sub-select.
- A comment above the first `PREFIX` makes the request return nothing.
- Large request bodies go via `--data-binary @file`; they exceed the argv limit.
- After a large `DELETE`, a full scan can return rows a pattern lookup no longer finds. Restart the store before an equality check.
