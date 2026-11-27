# app-lokale-verkenner

Backend of the Lokale Verkenner, a slimmed-down
version of app-organization-portal for local governments, economische actoren and other
organisations.

## Change requests

Every edit of organisation data is a change request, handled by
[change-request-service](https://github.com/lblod/change-request-service) at `/change-requests`.
The service checks who may edit what (own organisation; ABB edits all), keeps the request with its
steps and versions in `http://mu.semte.ch/graphs/change-requests`, and applies it to the
organisation data in `http://mu.semte.ch/graphs/administrative-unit`. An edit of an organisation's own data is
applied at once (a change someone made after the form was loaded refuses it with 409, and the
form is reloaded); edits are kept as the history of the data and are not listed with the requests
unless asked for (`filter[kind]=edit`). A request to register a new organisation or a
veranderingsgebeurtenis waits for ABB, who approves it, rejects it with a reason or asks for
information; the requester answers or contests a rejection (`POST /change-requests/:id/steps`).
Everyone who is logged in sees every request; who submitted it and the texts of its steps are
shown to its organisation and ABB only (`pendingVisibleTo` in the configuration switches the
pending ones to the involved organisations).

The organisation data is for logged-in sessions: it is in a graph of its own,
`http://mu.semte.ch/graphs/administrative-unit` (the graph OP keeps it in), which the `logged-in`
group reads. A visitor without a session reads the public graph only: the code lists, the
locations, the mock-login accounts and, of the organisation of a mock account, its type and uuid,
which the mock-login page needs. The resource routes are read-only: `config/authorization/config.lisp`
gives no one a write grant on the organisation data except the service, through its scope. Two
other services write with mu-auth-sudo, as in OP: scope-of-operation, which composes a
werkingsgebied, and kbo-data-sync, which fetches the KBO data of an organisation from Wegwijs
after a save with a KBO number and nightly; the exceptions and what each may write are described
in `config.lisp`.

## Search

The organisations overview and the organisation filters search `/search/organizations`, served by
mu-search on Elasticsearch. `config/search/config.json` defines the one index: the organisations as
a logged-in session reads them (the organisation graph and the public graph together: the
classification labels and the locations are in the public graph), OP's organisation index without
the worship types. The delta-notifier keeps it up to date (`config/delta/rules.js`). After a
change of the search configuration or a migration of organisation data (the migrations write
Virtuoso directly, so mu-search does not see them), rebuild it:

    /bin/bash scripts/reset-elastic.sh

Elasticsearch 9 does not run as root, so `data/elasticsearch` must exist and be writable by uid
1000 before the first `docker compose up` (which otherwise creates it as root, and Elasticsearch
dies on `node.lock`): `mkdir -p data/elasticsearch` and, on a server, `chown 1000
data/elasticsearch`. The script empties the directory but keeps it.

The service's configuration is `config/change-requests/change-requests.json`: the aggregates and
their kind, the fields each may change on an organisation (`writable`: the kerngegevens do not
change the werkingsgebied, the juridische vorm or the bijkomende kwalificaties, which change
through a veranderingsgebeurtenis), the classifications it registers and as which type
(`registration`, with the oprichting every new organisation carries and the classifications that
need no KBO number), which organisation may request which classification ("Wie beheert"), the ABB
organisation and the visibility. The same file is the service repository's
`config/change-requests.json`; keep the two equal. The service reads it and the resources model at
start-up: restart it after a change.

The data it writes (requests, steps, proposed versions, record states) is described in the
service's README and vocabulary; the two code lists it uses, the status of a request and the type
of a step, are loaded into the public graph by the migrations
`config/migrations/2026/20261015120000-add-change-request-code-lists.ttl`,
`20261020120000-add-validation-flow-code-lists.ttl` and the corrections after them.

## Development

With a checkout of change-request-service next to this repository (`../change-request-service`),
which `docker-compose.dev.yml` mounts into the template image:

    docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

The identifier listens on http://localhost:88, where the stack's frontend (lblod/frontend-lokale-verkenner)
answers, and Virtuoso on http://localhost:8899. Log in through mock-login (the frontend, or
`POST /mock/sessions`), then post change requests. For work on the frontend itself, run `ember serve`
from a checkout of frontend-lokale-verkenner against this stack instead. The service's
`scripts/e2e-mock-login.sh` runs the whole flow against this setup; run it while nobody else writes
to the stack. The organisations overview needs the search index: build it with
`scripts/reset-elastic.sh` once the migrations ran (see Search).

Deploying a version: the deploy notes in [CHANGELOG.md](CHANGELOG.md) list, per change, the
services to restart and the migrations to wait for.

## Sync data from OP

RVS is filled from OP's non-worship organisation data. Two `mu` commands and one manual
file move:

```sh
# in OP's project: start the store, then write data/dumps/<stamp>/
docker compose up -d triplestore project-scripts
mu script project-scripts export-to-rvs

# move data/dumps/<stamp>/ to this project's data/dumps/ (manual: separate compose networks)
mkdir -p data/dumps && cp -r <OP>/data/dumps/<stamp> data/dumps/

# in this project
docker compose up -d triplestore project-scripts
mu script project-scripts import-from-op --dump data/dumps/<stamp>
```

Prerequisites:

- the triplestore and the `project-scripts` container are running
  (`docker compose up -d triplestore project-scripts`);
- the dump folder lives inside this project, at `data/dumps/<stamp>/` — `--dump` takes that
  folder (it holds `op-rvs.nt` and `manifest.json`), and only this project is mounted in the
  script container, so a path into OP's checkout does not work;
- the seed migrations for units and classification codes live in `config/dev-migrations/`,
  which `docker-compose.dev.yml` mounts next to the shared set for local development;
  a local stack that imports a dump runs without that mount (see
  `config/project-scripts/import-from-op/README.md`, "Conflicting migrations");
- a read rule for `graphs/administrative-unit` exists in `config/authorization/`. Without
  it the import succeeds but the UI shows nothing.

A fresh dev database gets the seeded units and their mock-login accounts from
`config/dev-migrations/`; a developer who imports a dump instead comments that mount out
before the first start, and the accounts come from the migration that keys on the import
graph.

The import is additive and one-shot. Full procedure, flags, dry-run limits and the moved
migrations: `config/project-scripts/import-from-op/README.md`.
