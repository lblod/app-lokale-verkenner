# Changelog
## Unreleased
- Add the public-organization-data delta producer: publishes non-worship units, registered organisations, decisions and decision activities, identifiers, werkingsgebieden, sites, addresses and contact points for OP to consume. Memberships, bestuursorganen, mandates and posts stay out until Lokale Verkenner can edit them [RVS-29] [RVS-30]
- Bump delta-producer-publication-graph-maintainer to 1.4.4: filters the producer's export per resource [RVS-30]
- Publish the locations inside a composed werkingsgebied: OP reads the municipalities of a scope through them, and a scope composed only in Lokale Verkenner would otherwise reach OP without members [RVS-30]
- Set up mock-login [RVS-39]
- Add change-request-service 0.2.0: every edit of organisation data is a change request [RVS-28]
- New organisations and change events wait for validation by ABB; edits apply at once [RVS-9] [RVS-10]
- Configure per aggregate the fields it may change and the classifications it registers [RVS-37]
- Add scope-of-operation, kbo-data-sync and mu-search with Elasticsearch, as in OP [RVS-37]
- Move the organisation data from the public graph to graphs/administrative-unit, readable only when logged in [RVS-37]
- Sync the resources model with OP: document-links, resulting-name, periods-of-time with dates [OP-3925] [OP-3927] [OP-3947]
- Migrations: status labels of the validation flow, earlier requests set to afgehandeld, a second ABB mock account [RVS-37]
- Add the import-from-op mu-script; the seed migrations move to config/dev-migrations [RVS-40]
- Add mock-login accounts for the organisations an OP import brings in [RVS-40]
- Add the frontend, lblod/frontend-lokale-verkenner 0.0.2, to the stack

### Deploy notes
```
drc up -d frontend change-requests scope-of-operation kbo-data-sync project-scripts
drc up -d publication-triplestore jobs-controller file
drc up -d delta-producer-publication-graph-maintainer delta-producer-background-jobs-initiator delta-producer-dump-file-publisher
drc restart database                                      # config.lisp: the organisation graph and the logged-in group
drc restart resource dispatcher delta-notifier            # resources model, routes, delta rule of the search index
drc restart migrations                                    # wait for "All migrations executed"
/bin/bash scripts/reset-elastic.sh                        # last: creates data/elasticsearch, builds the index, ends with "up -d"
```
To fill an environment from OP: `config/project-scripts/import-from-op/README.md`.

To publish organisations for OP's consumers, trigger the initial sync job and wait until it ends; it already writes the dump:
```
drc exec delta-producer-background-jobs-initiator curl -X POST http://localhost/public-organization-data/initial-sync-jobs
```
OP's Lokale Verkenner consumers ship with `DCR_DISABLE_INITIAL_SYNC: "true"`; their `docker-compose.override.yml`
must set it to `"false"` before they sync from this environment (see the deploy notes of `app-organization-portal`).

The producer exports a werkingsgebied's locations, not just the scope: OP resolves the municipalities of a scope
through their `sfWithin` links, so a scope composed only here (not in OP) needs those links published. The filter on
the `prov:Location` entry admits the composed scopes and the locations that point at one; the base set of gemeenten,
provincies and regio's stays OP's and is not republished.
